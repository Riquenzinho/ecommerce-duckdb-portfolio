-- prata.sessoes: sessões do site e do aplicativo, uma linha por dia + dispositivo.
-- Origem: bronze.sessoes (dados_origem/sessoes.xlsx)
--
-- Regras:
--   - A data vem como número (20230105) e vira DATE.
--   - Dispositivo em minúsculo ("APP", "Mobile" -> "app", "mobile").
--   - A linha "Total" do fim do Excel não entra.
--   - Dia + dispositivo repetido (com números diferentes): fica a PRIMEIRA linha. Não há como
--     saber qual é a certa; a conferência mostra quantos dias tiveram repetição.

CREATE TABLE prata.sessoes (
    data            DATE NOT NULL,
    dispositivo     VARCHAR NOT NULL,
    sessoes         INTEGER,
    usuarios        INTEGER,
    novos_usuarios  INTEGER,
    pedidos         INTEGER,
    receita         DECIMAL(14, 2),
    _linha_excel    INTEGER NOT NULL,
    PRIMARY KEY (data, dispositivo)
);

INSERT INTO prata.sessoes
SELECT
    prata.data("Data")                  AS data,
    lower(prata.texto("Dispositivo"))   AS dispositivo,
    prata.inteiro("Sessões")            AS sessoes,
    prata.inteiro("Usuários")           AS usuarios,
    prata.inteiro("Novos Usuários")     AS novos_usuarios,
    prata.inteiro("Pedidos")            AS pedidos,
    prata.dinheiro("Receita")           AS receita,
    CAST("_linha_excel" AS INTEGER)     AS _linha_excel
FROM (SELECT COLUMNS(*)::VARCHAR FROM bronze.sessoes)
WHERE lower(prata.texto("Data")) <> 'total'
QUALIFY row_number() OVER (PARTITION BY prata.data("Data"), lower(prata.texto("Dispositivo"))
                           ORDER BY CAST("_linha_excel" AS INTEGER)) = 1;
