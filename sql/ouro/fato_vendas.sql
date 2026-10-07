-- ouro.fato_vendas: uma linha por item de pedido.
-- Chaves para as dimensões: data_pedido (dim_calendario), sku (dim_produto),
-- id_cliente (dim_cliente), origem_midia (dim_canal_marketing).
--
-- Receita = SUM(valor_item) com venda_valida = 'Verdadeiro'.
-- Frete e total do pedido NÃO estão aqui (se repetiriam em cada item): use ouro.fato_pedidos.

CREATE VIEW ouro.fato_vendas AS
SELECT
    pedido,
    item,
    data_pedido,
    sku,
    id_cliente,
    origem || ' / ' || midia                    AS origem_midia,
    status,
    ouro.venda_valida(status)                   AS venda_valida,
    canal,
    campanha,
    cupom,
    forma_pagamento,
    quantidade,
    preco_unitario,
    CAST(quantidade * preco_unitario AS DECIMAL(14, 2))  AS valor_bruto,
    desconto,
    valor_item
FROM prata.vendas;
