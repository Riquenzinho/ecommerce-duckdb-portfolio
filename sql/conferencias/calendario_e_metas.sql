-- Conferências do calendário e das metas. Cada linha: (conferencia, quantidade, tipo).

WITH datas_das_tabelas AS (
    SELECT data_pedido AS data FROM prata.vendas
    UNION SELECT data FROM prata.sessoes
    UNION SELECT data FROM prata.marketing
    UNION SELECT data FROM prata.metas
)
SELECT 'calendário: dia faltando entre 01/01/2023 e 31/12 do ano atual' AS conferencia,
       (SELECT (make_date(year(current_date), 12, 31) - DATE '2023-01-01' + 1) - COUNT(*)
        FROM prata.calendario) AS quantidade,
       'atenção' AS tipo
UNION ALL
SELECT 'calendário: data das tabelas fora do calendário (sumiria num JOIN)',
       (SELECT COUNT(*) FROM datas_das_tabelas WHERE data NOT IN (SELECT data FROM prata.calendario)), 'atenção'
UNION ALL
SELECT 'metas: dia sem meta (entre a primeira e a última meta)',
       (SELECT COUNT(*) FROM prata.calendario
        WHERE data BETWEEN (SELECT MIN(data) FROM prata.metas) AND (SELECT MAX(data) FROM prata.metas)
          AND data NOT IN (SELECT data FROM prata.metas)), 'atenção';
