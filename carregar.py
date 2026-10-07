"""
Carrega os Excel de dados_origem no banco livraria.duckdb, em camadas:

  bronze  cópia fiel de cada aba do Excel, gravada em bronze/<tabela>.parquet, mais as colunas
          de rastreio _linha_excel, _arquivo_origem e _carregado_em. No banco, bronze.<tabela>
          é uma VIEW que lê o Parquet.
  prata   tratamentos: tipos, nomes, regras, chaves (sql/prata/*.sql)
  ouro    versão final para consulta (sql/ouro/*.sql)

Carga incremental: bronze/_controle.json guarda a impressão digital (SHA-256) de cada Excel.
Só é relido o arquivo cujo CONTEÚDO mudou (a data do arquivo muda ao copiar ou sincronizar,
o conteúdo não).

O banco é montado num arquivo temporário, que só substitui o oficial no final: se algo
falhar, o banco anterior continua intacto.

Uso:
  python carregar.py          relê os Excel que mudaram e remonta o banco
  python carregar.py --tudo   relê todos os Excel
"""
import argparse
import datetime as dt
import hashlib
import json
import os
import sys
import time
from pathlib import Path

import duckdb
import pandas as pd

from config import BASES

RAIZ = Path(__file__).parent
ORIGEM = RAIZ / "dados_origem"
BRONZE = RAIZ / "bronze"
CONTROLE = BRONZE / "_controle.json"
SQL = RAIZ / "sql"
BANCO = RAIZ / "livraria.duckdb"
BANCO_TEMPORARIO = RAIZ / "livraria.tmp.duckdb"


# ---------------------------------------------------------------------------------------
# Bronze
# ---------------------------------------------------------------------------------------

def impressao_digital(caminho):
    """SHA-256 do arquivo: muda se, e só se, o conteúdo mudar."""
    resumo = hashlib.sha256()
    with open(caminho, "rb") as arquivo:
        for bloco in iter(lambda: arquivo.read(8 * 1024 * 1024), b""):
            resumo.update(bloco)
    return resumo.hexdigest()


def ler_aba(caminho, aba, linha_cabecalho):
    """Lê a aba como está no Excel e acrescenta as colunas de rastreio."""
    tabela = pd.read_excel(caminho, sheet_name=aba, header=linha_cabecalho - 1, engine="calamine")
    for coluna in tabela.columns[tabela.dtypes == object]:
        tipos = {type(valor) for valor in tabela[coluna].dropna()}
        if len(tipos) != 1:
            # número e texto misturados (ou coluna vazia): vira texto, porque o Parquet exige
            # um tipo por coluna. Quem converte para o tipo certo é a prata.
            tabela[coluna] = tabela[coluna].map(lambda v: None if pd.isna(v) else str(v)).astype("string")
    tabela["_linha_excel"] = range(linha_cabecalho + 1, linha_cabecalho + 1 + len(tabela))
    tabela["_arquivo_origem"] = caminho.relative_to(ORIGEM).as_posix()
    tabela["_carregado_em"] = dt.datetime.now().replace(microsecond=0)
    return tabela


def atualizar_bronze(reler_tudo):
    BRONZE.mkdir(exist_ok=True)
    controle = json.loads(CONTROLE.read_text(encoding="utf-8")) if CONTROLE.exists() else {}
    digitais = {}                                   # um arquivo pode ter várias abas: calcula uma vez
    for tabela, (arquivo, aba, linha_cabecalho) in BASES.items():
        caminho = ORIGEM / arquivo
        if not caminho.exists():
            sys.exit(f"Não encontrei {caminho}. Rode antes: python gerar_dados.py")
        if caminho not in digitais:
            digitais[caminho] = impressao_digital(caminho)
        anterior = controle.get(tabela, {})
        parquet = BRONZE / f"{tabela}.parquet"
        mudou = (reler_tudo or not parquet.exists() or anterior.get("conteudo") != digitais[caminho]
                 or [anterior.get("arquivo"), anterior.get("aba"), anterior.get("linha_cabecalho")]
                 != [arquivo, aba, linha_cabecalho])
        if not mudou:
            print(f"  bronze.{tabela:<20} sem mudança   {anterior['linhas']:>9,} linhas")
            continue

        inicio = time.time()
        dados = ler_aba(caminho, aba, linha_cabecalho)
        temporario = parquet.with_suffix(".tmp")
        dados.to_parquet(temporario, index=False)
        os.replace(temporario, parquet)
        controle[tabela] = {"arquivo": arquivo, "aba": aba, "linha_cabecalho": linha_cabecalho,
                            "conteudo": digitais[caminho], "linhas": len(dados),
                            "carregado_em": dt.datetime.now().isoformat(timespec="seconds")}
        CONTROLE.write_text(json.dumps(controle, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"  bronze.{tabela:<20} RELIDO        {len(dados):>9,} linhas  ({time.time() - inicio:.0f} s)")


# ---------------------------------------------------------------------------------------
# Banco
# ---------------------------------------------------------------------------------------

def executar_camada(con, camada):
    """Roda os .sql da pasta em ordem alfabética (arquivos que começam com "_" vêm antes)."""
    pasta = SQL / camada
    for arquivo in sorted(pasta.glob("*.sql")) if pasta.exists() else []:
        try:
            con.execute(arquivo.read_text(encoding="utf-8"))
        except duckdb.Error as erro:
            raise SystemExit(f"\nErro em sql/{camada}/{arquivo.name}:\n{erro}\n\n"
                             f"O banco anterior continua intacto.")


def conferir(con):
    """Roda sql/conferencias/*.sql. Cada uma devolve linhas (conferencia, quantidade, tipo):
    'tratado' = sujeira conhecida que a prata resolveu; 'atenção' = precisa de alguém."""
    print("\nConferências:")
    precisam_de_atencao = 0
    for arquivo in sorted((SQL / "conferencias").glob("*.sql")):
        try:
            resultado = con.execute(arquivo.read_text(encoding="utf-8")).fetchall()
        except duckdb.Error as erro:
            raise SystemExit(f"\nErro em sql/conferencias/{arquivo.name}:\n{erro}\n\n"
                             f"O banco anterior continua intacto.")
        for conferencia, quantidade, tipo in resultado:
            if not quantidade:
                situacao = "ok"
            elif tipo == "tratado":
                situacao = f"tratado: {quantidade:,}"
            else:
                situacao = f"ATENÇÃO: {quantidade:,}"
                precisam_de_atencao += 1
            print(f"  {conferencia:<72} {situacao}")
    return precisam_de_atencao


def montar_banco():
    BANCO_TEMPORARIO.unlink(missing_ok=True)
    con = duckdb.connect(str(BANCO_TEMPORARIO))
    for camada in ("bronze", "prata", "ouro"):
        con.execute(f"CREATE SCHEMA {camada}")
    for tabela in BASES:
        parquet = (BRONZE / f"{tabela}.parquet").resolve().as_posix()
        con.execute(f"CREATE VIEW bronze.{tabela} AS SELECT * FROM read_parquet('{parquet}')")
    executar_camada(con, "prata")
    executar_camada(con, "ouro")

    print()
    for camada, tabela in con.execute("""
            SELECT camada, tabela FROM (
                SELECT schema_name AS camada, table_name AS tabela FROM duckdb_tables()
                UNION ALL
                SELECT schema_name, view_name FROM duckdb_views() WHERE NOT internal)
            ORDER BY list_position(['bronze', 'prata', 'ouro'], camada), tabela""").fetchall():
        linhas = con.execute(f"SELECT COUNT(*) FROM {camada}.{tabela}").fetchone()[0]
        print(f"  {camada}.{tabela:<20} {linhas:>9,} linhas")
    precisam_de_atencao = conferir(con)
    con.close()

    try:
        os.replace(BANCO_TEMPORARIO, BANCO)
    except PermissionError:
        sys.exit(f"\nNão consegui trocar o {BANCO.name}: ele está aberto em outro programa "
                 f"(DBeaver?). Feche a conexão e rode de novo.")
    if precisam_de_atencao:
        print(f"\n>>> {precisam_de_atencao} conferência(s) com ATENÇÃO. O banco foi atualizado mesmo assim.")


def main():
    argumentos = argparse.ArgumentParser(description="Carrega os Excel no banco livraria.duckdb")
    argumentos.add_argument("--tudo", action="store_true", help="relê todos os Excel")
    reler_tudo = argumentos.parse_args().tudo

    inicio = time.time()
    print("Bronze (Excel -> Parquet):")
    atualizar_bronze(reler_tudo)
    montar_banco()
    print(f"\nBanco atualizado em {time.time() - inicio:.0f} s: {BANCO}")


if __name__ == "__main__":
    main()
