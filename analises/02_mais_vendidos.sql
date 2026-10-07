-- Pergunta: quais livros e categorias mais venderam em 2025? Quanto o e-book representa?
--
-- Usa: ouro.fato_vendas (uma linha por item) e ouro.dim_produto.
-- Receita de produto = SUM(valor_item) com venda_valida = 'Verdadeiro' (sem frete).

-- 1) Top 10 livros (somando os formatos: capa comum, capa dura e e-book)
SELECT
    pr.titulo,
    pr.autor,
    pr.categoria,
    SUM(v.quantidade)       AS exemplares,
    SUM(v.valor_item)       AS receita
FROM ouro.fato_vendas AS v
JOIN ouro.dim_produto AS pr USING (sku)
WHERE v.venda_valida = 'Verdadeiro' AND year(v.data_pedido) = 2025
GROUP BY ALL
ORDER BY receita DESC
LIMIT 10;

-- 2) Categorias: receita, participação e quanto vem de e-book
SELECT
    pr.categoria,
    SUM(v.valor_item)                                                       AS receita,
    ROUND(SUM(v.valor_item) / SUM(SUM(v.valor_item)) OVER () * 100, 1)      AS pct_da_receita,
    ROUND(SUM(v.valor_item) FILTER (WHERE pr.formato = 'E-book')
          / SUM(v.valor_item) * 100, 1)                                     AS pct_e_book
FROM ouro.fato_vendas AS v
JOIN ouro.dim_produto AS pr USING (sku)
WHERE v.venda_valida = 'Verdadeiro' AND year(v.data_pedido) = 2025
GROUP BY pr.categoria
ORDER BY receita DESC;
