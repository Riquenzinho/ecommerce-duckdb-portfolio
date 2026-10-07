-- Pergunta: de onde vem a receita? Quanto a ferramenta de análise (marketing) deixa de
-- registrar em relação às vendas reais?
--
-- Usa: ouro.fato_pedidos (vendas reais), ouro.fato_marketing (o que a ferramenta registrou)
-- e ouro.dim_canal_marketing. Cada fato é somado por canal ANTES de juntar.
-- A ferramenta registra o pedido na hora da compra, inclusive os que depois são cancelados:
-- por isso o % registrado compara com TODOS os pedidos, e a receita, só com as vendas válidas.

WITH vendas AS (
    SELECT d.canal,
           SUM(p.valor_total) FILTER (WHERE p.venda_valida = 'Verdadeiro')  AS receita_vendas,
           COUNT(*) FILTER (WHERE p.venda_valida = 'Verdadeiro')            AS pedidos,
           SUM(p.valor_total)                                               AS receita_todos_os_pedidos
    FROM ouro.fato_pedidos AS p
    JOIN ouro.dim_canal_marketing AS d USING (origem_midia)
    WHERE year(p.data_pedido) = 2025
    GROUP BY d.canal
),
marketing AS (
    SELECT COALESCE(d.canal, '(sem origem no Excel)') AS canal,
           SUM(m.sessoes) AS sessoes, SUM(m.transacoes) AS transacoes, SUM(m.receita) AS receita_registrada
    FROM ouro.fato_marketing AS m
    LEFT JOIN ouro.dim_canal_marketing AS d USING (origem_midia)
    WHERE year(m.data) = 2025
    GROUP BY 1
)
SELECT
    canal,
    receita_vendas,
    ROUND(receita_vendas / SUM(receita_vendas) OVER () * 100, 1)    AS pct_da_receita,
    pedidos,
    ROUND(receita_vendas / pedidos, 2)                              AS ticket_medio,
    sessoes,
    ROUND(transacoes / sessoes * 100, 2)                            AS conversao_pct,
    ROUND(receita_registrada / receita_todos_os_pedidos * 100, 1)   AS pct_registrado_pela_ferramenta
FROM vendas
FULL JOIN marketing USING (canal)
ORDER BY receita_vendas DESC NULLS LAST;
