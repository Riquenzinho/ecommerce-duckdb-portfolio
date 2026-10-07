-- Conferências do modelo estrela (ouro). Cada linha: (conferencia, quantidade, tipo).
-- Chave de fato sem par na dimensão faz a linha "sumir" num relatório (Power BI, JOIN).

SELECT 'ouro: chave da dimensão repetida (dim_produto, dim_cliente, dim_canal, dim_calendario)' AS conferencia,
       (SELECT COUNT(*) - COUNT(DISTINCT sku) FROM ouro.dim_produto)
     + (SELECT COUNT(*) - COUNT(DISTINCT id_cliente) FROM ouro.dim_cliente)
     + (SELECT COUNT(*) - COUNT(DISTINCT origem_midia) FROM ouro.dim_canal_marketing)
     + (SELECT COUNT(*) - COUNT(DISTINCT data) FROM ouro.dim_calendario) AS quantidade,
       'atenção' AS tipo
UNION ALL
SELECT 'ouro: fato_vendas com sku fora da dim_produto',
       (SELECT COUNT(*) FROM ouro.fato_vendas WHERE sku NOT IN (SELECT sku FROM ouro.dim_produto)), 'atenção'
UNION ALL
SELECT 'ouro: fatos com origem/mídia fora da dim_canal_marketing',
       (SELECT COUNT(*) FROM (SELECT origem_midia FROM ouro.fato_pedidos UNION ALL
                              SELECT origem_midia FROM ouro.fato_marketing WHERE origem_midia IS NOT NULL)
        WHERE origem_midia NOT IN (SELECT origem_midia FROM ouro.dim_canal_marketing)), 'atenção'
UNION ALL
SELECT 'ouro: pedido com valor_total diferente de valor_produtos + frete',
       (SELECT COUNT(*) FROM ouro.fato_pedidos WHERE abs(valor_total - (valor_produtos + frete)) > 0.01), 'atenção'
UNION ALL
SELECT 'ouro: pedido com campo do pedido diferente entre os itens',
       (SELECT COUNT(*) FROM (SELECT pedido FROM prata.vendas GROUP BY pedido
                              HAVING COUNT(DISTINCT (status, data_pedido, id_cliente, frete_pedido, valor_total_pedido)) > 1)),
       'atenção'
UNION ALL
SELECT 'ouro: soma de valor_item diferente entre fato_vendas e fato_pedidos',
       (SELECT CASE WHEN (SELECT SUM(valor_item) FROM ouro.fato_vendas)
                       = (SELECT SUM(valor_produtos) FROM ouro.fato_pedidos) THEN 0 ELSE 1 END), 'atenção';
