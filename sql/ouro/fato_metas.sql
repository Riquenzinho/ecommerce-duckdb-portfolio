-- ouro.fato_metas: metas diárias. Uma linha por dia.
-- Chave para a dimensão: data (dim_calendario).
-- Compare com ouro.fato_pedidos (venda_valida = 'Verdadeiro') e ouro.fato_sessoes.

CREATE VIEW ouro.fato_metas AS
SELECT
    data,
    meta_receita,
    meta_pedidos,
    meta_sessoes
FROM prata.metas;
