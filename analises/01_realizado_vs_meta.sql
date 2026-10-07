-- Pergunta: a loja bateu a meta de receita em 2025? Em quais meses ficou mais longe?
--
-- Usa: ouro.fato_pedidos (receita com frete, só venda válida), ouro.fato_metas, ouro.dim_calendario.
-- A meta é diária; soma-se por mês dos dois lados antes de comparar (somar antes de juntar
-- evita multiplicar linhas no JOIN).

WITH realizado AS (
    SELECT cal.ano_mes, SUM(p.valor_total) AS receita, COUNT(*) AS pedidos
    FROM ouro.fato_pedidos AS p
    JOIN ouro.dim_calendario AS cal ON cal.data = p.data_pedido
    WHERE p.venda_valida = 'Verdadeiro' AND cal.ano = 2025
    GROUP BY cal.ano_mes
),
meta AS (
    SELECT cal.ano_mes, SUM(m.meta_receita) AS meta_receita, SUM(m.meta_pedidos) AS meta_pedidos,
           COUNT(*) FILTER (WHERE cal.dia_util = 'Verdadeiro') AS dias_uteis
    FROM ouro.fato_metas AS m
    JOIN ouro.dim_calendario AS cal ON cal.data = m.data
    WHERE cal.ano = 2025
    GROUP BY cal.ano_mes
)
SELECT
    ano_mes,
    dias_uteis,
    receita,
    meta_receita,
    ROUND(receita / meta_receita * 100, 1)      AS pct_meta_receita,
    pedidos,
    meta_pedidos,
    ROUND(pedidos / meta_pedidos * 100, 1)      AS pct_meta_pedidos
FROM realizado
JOIN meta USING (ano_mes)
ORDER BY ano_mes;
