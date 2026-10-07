-- Perguntas: quanto tempo a entrega leva em cada região? Qual forma de pagamento cancela mais?
--
-- Usa: ouro.fato_pedidos e ouro.dim_cliente.
-- prazo_entrega_dias só existe para pedido entregue ou devolvido; e-book (entrega "Digital")
-- fica de fora do prazo. tipo_entrega só existe a partir de 2024.

-- 1) Prazo de entrega por região e tipo de entrega (2024 e 2025)
SELECT
    cl.regiao,
    p.tipo_entrega,
    COUNT(*)                                    AS pedidos_entregues,
    ROUND(AVG(p.prazo_entrega_dias), 1)         AS prazo_medio_dias,
    quantile_cont(p.prazo_entrega_dias, 0.9)    AS prazo_90_pct_dos_pedidos
FROM ouro.fato_pedidos AS p
JOIN ouro.dim_cliente AS cl USING (id_cliente)
WHERE p.prazo_entrega_dias IS NOT NULL AND p.tipo_entrega IN ('Normal', 'Expressa')
GROUP BY ALL
ORDER BY p.tipo_entrega, prazo_medio_dias;

-- 2) Cancelamento por forma de pagamento
SELECT
    forma_pagamento,
    COUNT(*)                                                                AS pedidos,
    ROUND(COUNT(*) FILTER (WHERE status = 'Cancelado') / COUNT(*) * 100, 1) AS pct_cancelado
FROM ouro.fato_pedidos
GROUP BY forma_pagamento
ORDER BY pct_cancelado DESC;
