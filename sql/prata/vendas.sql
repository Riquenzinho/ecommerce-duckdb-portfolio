-- prata.vendas: itens de pedido de 2023 a 2025, uma linha por item.
-- Origem: bronze.vendas_2023, _2024 e _2025 (dados_origem/vendas/vendas_AAAA.xlsx)
--
-- Regras:
--   - Os 3 anos são empilhados pelo nome da coluna. Tudo é lido como texto, para o tipo não
--     depender de como cada Excel guardou o dado (em 2023 a data e parte dos preços são texto).
--   - Colunas e ordem = as do Excel mais novo (2025). Coluna que não existe num ano fica NULL:
--     canal e tipo_entrega começaram em 2024; avaliacao, em 2025. "Obs Interna" (só 2023)
--     não entra: continua em bronze.vendas_2023.
--   - "Pagamento" (2025) e "Forma de Pagamento" (2023 e 2024) são a mesma coluna.
--   - Pedido + item repetido (o dia 11/03/2024 está colado duas vezes no Excel): fica a
--     primeira linha. A chave (pedido, item) garante que não sobra repetição.
--   - Status numa grafia só ("ENTREGUE", "entregue " -> "Entregue"); UF por extenso vira
--     sigla; CEP com 8 dígitos; acentos corrompidos do título corrigidos.
--   - Dinheiro em DECIMAL(14,2): valor exato, sem as "sobras" de casas decimais do DOUBLE.
--   - frete_pedido e valor_total_pedido são do PEDIDO e se repetem em cada item. Não somar
--     direto: para receita use SUM(valor_item); para frete, um valor por pedido.

CREATE TABLE prata.vendas (
    pedido              VARCHAR NOT NULL,
    item                INTEGER NOT NULL,
    data_pedido         DATE NOT NULL,
    status              VARCHAR NOT NULL,
    id_cliente          VARCHAR NOT NULL,
    uf                  VARCHAR,
    cidade              VARCHAR,
    cep                 VARCHAR,
    canal               VARCHAR,
    origem              VARCHAR,
    midia               VARCHAR,
    campanha            VARCHAR,
    cupom               VARCHAR,
    forma_pagamento     VARCHAR,
    parcelas            INTEGER,
    sku                 VARCHAR NOT NULL,
    produto             VARCHAR,
    formato             VARCHAR,
    quantidade          INTEGER NOT NULL,
    preco_unitario      DECIMAL(14, 2) NOT NULL,
    desconto            DECIMAL(14, 2),
    valor_item          DECIMAL(14, 2) NOT NULL,
    tipo_entrega        VARCHAR,
    frete_pedido        DECIMAL(14, 2),
    valor_total_pedido  DECIMAL(14, 2),
    data_entrega        DATE,
    avaliacao           INTEGER,
    ano_arquivo         INTEGER NOT NULL,   -- de qual Excel a linha veio
    _linha_excel        INTEGER NOT NULL,   -- linha nesse Excel
    PRIMARY KEY (pedido, item)
);

INSERT INTO prata.vendas
WITH empilhado AS (
    SELECT 2023 AS ano_arquivo, COLUMNS(*)::VARCHAR FROM bronze.vendas_2023
    UNION ALL BY NAME
    SELECT 2024 AS ano_arquivo, COLUMNS(*)::VARCHAR FROM bronze.vendas_2024
    UNION ALL BY NAME
    SELECT 2025 AS ano_arquivo, COLUMNS(*)::VARCHAR FROM bronze.vendas_2025
)
SELECT
    prata.texto("Pedido")                                       AS pedido,
    prata.inteiro("Item")                                       AS item,
    prata.data("Data do Pedido")                                AS data_pedido,
    prata.frase("Status")                                       AS status,
    prata.codigo("ID Cliente")                                  AS id_cliente,
    prata.uf("UF")                                              AS uf,
    prata.um_espaco("Cidade")                                   AS cidade,
    prata.cep("CEP")                                            AS cep,
    prata.frase("Canal")                                        AS canal,
    lower(prata.texto("Origem"))                                AS origem,
    lower(prata.texto("Mídia"))                                 AS midia,
    lower(prata.texto("Campanha"))                              AS campanha,
    upper(prata.texto("Cupom"))                                 AS cupom,
    prata.frase(COALESCE("Pagamento", "Forma de Pagamento"))    AS forma_pagamento,
    prata.inteiro("Parcelas")                                   AS parcelas,
    prata.codigo("SKU")                                         AS sku,
    prata.corrigir_acentos(prata.um_espaco("Produto"))          AS produto,
    prata.frase("Formato")                                      AS formato,
    prata.inteiro("Quantidade")                                 AS quantidade,
    prata.dinheiro("Preço Unitário")                            AS preco_unitario,
    prata.dinheiro("Desconto")                                  AS desconto,
    prata.dinheiro("Valor Item")                                AS valor_item,
    prata.frase("Tipo de Entrega")                              AS tipo_entrega,
    prata.dinheiro("Frete Pedido")                              AS frete_pedido,
    prata.dinheiro("Valor Total Pedido")                        AS valor_total_pedido,
    prata.data("Data de Entrega")                               AS data_entrega,
    prata.inteiro("Avaliação")                                  AS avaliacao,
    ano_arquivo,
    CAST("_linha_excel" AS INTEGER)                             AS _linha_excel
FROM empilhado
QUALIFY row_number() OVER (PARTITION BY prata.texto("Pedido"), prata.inteiro("Item")
                           ORDER BY ano_arquivo, CAST("_linha_excel" AS INTEGER)) = 1;
