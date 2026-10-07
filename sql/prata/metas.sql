-- prata.metas: metas diárias de receita, pedidos e sessões. Uma linha por dia.
-- Origem: bronze.metas (dados_origem/metas.xlsx)
-- A conferência avisa se faltar algum dia (no Excel atual falta 29/02/2024).

CREATE TABLE prata.metas (
    data            DATE PRIMARY KEY,
    meta_receita    DECIMAL(14, 2),
    meta_pedidos    INTEGER,
    meta_sessoes    INTEGER,
    _linha_excel    INTEGER NOT NULL
);

INSERT INTO prata.metas
SELECT
    prata.data("Data")                  AS data,
    prata.dinheiro("Meta Receita")      AS meta_receita,
    prata.inteiro("Meta Pedidos")       AS meta_pedidos,
    prata.inteiro("Meta Sessões")       AS meta_sessoes,
    CAST("_linha_excel" AS INTEGER)     AS _linha_excel
FROM (SELECT COLUMNS(*)::VARCHAR FROM bronze.metas);
