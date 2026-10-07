-- Pergunta: quanto as datas comerciais (Black Friday, Dia do Livro...) vendem a mais que um dia comum?
--
-- Usa: ouro.fato_pedidos e ouro.dim_calendario (coluna data_comercial).
-- "Dia comum" = média dos dias do mesmo ano sem data comercial e sem feriado.
-- Leitura: as datas de promoção da própria loja (Black Friday, Dia do Livro) vendem várias
-- vezes um dia comum. Datas de presente (Mães, Páscoa, Natal) vendem MENOS no próprio dia:
-- o livro é comprado antes, e o dia cai em domingo ou feriado.

WITH por_dia AS (
    SELECT cal.data, cal.ano, cal.data_comercial, cal.feriado,
           COUNT(p.pedido) AS pedidos, COALESCE(SUM(p.valor_total), 0) AS receita
    FROM ouro.dim_calendario AS cal
    LEFT JOIN ouro.fato_pedidos AS p ON p.data_pedido = cal.data AND p.venda_valida = 'Verdadeiro'
    WHERE cal.ano BETWEEN 2023 AND 2025
    GROUP BY ALL
),
dia_comum AS (
    SELECT ano, AVG(receita) AS receita_media
    FROM por_dia
    WHERE data_comercial IS NULL AND feriado = 'Falso'
    GROUP BY ano
)
SELECT
    d.data_comercial,
    ROUND(AVG(d.receita), 2)                                    AS receita_media_no_dia,
    ROUND(AVG(d.receita / c.receita_media), 2)                  AS vezes_um_dia_comum
FROM por_dia AS d
JOIN dia_comum AS c USING (ano)
WHERE d.data_comercial IS NOT NULL
GROUP BY d.data_comercial
ORDER BY vezes_um_dia_comum DESC;
