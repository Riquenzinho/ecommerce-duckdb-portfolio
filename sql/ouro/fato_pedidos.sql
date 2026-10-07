-- ouro.fato_pedidos: uma linha por pedido.
-- Chaves para as dimensões: data_pedido (dim_calendario), id_cliente (dim_cliente),
-- origem_midia (dim_canal_marketing).
--
-- Aqui o frete aparece UMA vez por pedido (no Excel ele se repete em cada item).
-- valor_total = valor_produtos + frete (a conferência confere).
-- primeira_compra = 'Verdadeiro' no primeiro pedido de cada cliente (base para recompra).

CREATE VIEW ouro.fato_pedidos AS
SELECT
    pedido,
    data_pedido,
    id_cliente,
    origem_midia,
    status,
    ouro.venda_valida(status)                                       AS venda_valida,
    canal,
    campanha,
    cupom,
    forma_pagamento,
    parcelas,
    tipo_entrega,
    itens,
    quantidade,
    valor_produtos,
    desconto,
    frete,
    valor_total,
    data_entrega,
    data_entrega - data_pedido                                      AS prazo_entrega_dias,
    avaliacao,
    CASE WHEN row_number() OVER (PARTITION BY id_cliente ORDER BY data_pedido, pedido) = 1
         THEN 'Verdadeiro' ELSE 'Falso' END                         AS primeira_compra
FROM (
    -- os campos do pedido se repetem em cada item: any_value pega um deles
    SELECT
        pedido,
        any_value(data_pedido)                  AS data_pedido,
        any_value(id_cliente)                   AS id_cliente,
        any_value(origem || ' / ' || midia)     AS origem_midia,
        any_value(status)                       AS status,
        any_value(canal)                        AS canal,
        any_value(campanha)                     AS campanha,
        any_value(cupom)                        AS cupom,
        any_value(forma_pagamento)              AS forma_pagamento,
        any_value(parcelas)                     AS parcelas,
        any_value(tipo_entrega)                 AS tipo_entrega,
        COUNT(*)                                AS itens,
        SUM(quantidade)                         AS quantidade,
        SUM(valor_item)                         AS valor_produtos,
        SUM(desconto)                           AS desconto,
        any_value(frete_pedido)                 AS frete,
        any_value(valor_total_pedido)           AS valor_total,
        any_value(data_entrega)                 AS data_entrega,
        any_value(avaliacao)                    AS avaliacao
    FROM prata.vendas
    GROUP BY pedido
);
