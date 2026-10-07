-- Pergunta: os clientes voltam a comprar? A retenção está melhorando?
--
-- Análise de safra (cohort): cada cliente entra na safra do trimestre da primeira compra.
-- Para cada safra: quantos clientes novos e quantos fizeram a 2ª compra em até 90 dias e
-- em até 1 ano. Safra sem 1 ano completo de observação fica vazia (não dá para medir ainda).
--
-- Usa: ouro.fato_pedidos (só venda válida) e ouro.dim_calendario.

WITH ordem AS (
    SELECT id_cliente, data_pedido,
           row_number() OVER (PARTITION BY id_cliente ORDER BY data_pedido, pedido) AS n
    FROM ouro.fato_pedidos
    WHERE venda_valida = 'Verdadeiro'
),
cliente AS (
    SELECT id_cliente,
           MIN(data_pedido) FILTER (WHERE n = 1) AS primeira,
           MIN(data_pedido) FILTER (WHERE n = 2) AS segunda
    FROM ordem
    GROUP BY id_cliente
),
ultimo_dia AS (SELECT MAX(data_pedido) AS dia FROM ouro.fato_pedidos)
SELECT
    cal.ano_trimestre                                                       AS safra,
    COUNT(*)                                                                AS clientes_novos,
    CASE WHEN MAX(c.primeira) + 90 <= (SELECT dia FROM ultimo_dia) THEN
        ROUND(COUNT(*) FILTER (WHERE c.segunda - c.primeira <= 90) / COUNT(*) * 100, 1)
    END                                                                     AS pct_voltou_em_90_dias,
    CASE WHEN MAX(c.primeira) + 365 <= (SELECT dia FROM ultimo_dia) THEN
        ROUND(COUNT(*) FILTER (WHERE c.segunda - c.primeira <= 365) / COUNT(*) * 100, 1)
    END                                                                     AS pct_voltou_em_1_ano
FROM cliente AS c
JOIN ouro.dim_calendario AS cal ON cal.data = c.primeira
GROUP BY cal.ano_trimestre
ORDER BY safra;
