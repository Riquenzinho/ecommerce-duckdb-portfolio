-- Conferências de prata.sessoes. Cada linha: (conferencia, quantidade, tipo).

SELECT 'sessões: dia + dispositivo repetido no Excel (fica a primeira linha)' AS conferencia,
       (SELECT COUNT(*) FROM bronze.sessoes WHERE lower(CAST("Data" AS VARCHAR)) <> 'total')
       - (SELECT COUNT(*) FROM prata.sessoes) AS quantidade,
       'tratado' AS tipo
UNION ALL
SELECT 'sessões: dispositivo escrito fora do padrão no Excel (padronizado)',
       (SELECT COUNT(*) FROM bronze.sessoes WHERE "Dispositivo" <> lower("Dispositivo")), 'tratado'
UNION ALL
SELECT 'sessões: dia sem os 4 dispositivos (desktop, mobile, tablet, app)',
       (SELECT COUNT(*) FROM (SELECT data FROM prata.sessoes GROUP BY data HAVING COUNT(*) <> 4)), 'atenção'
UNION ALL
SELECT 'sessões: dispositivo fora da lista conhecida',
       (SELECT COUNT(*) FROM prata.sessoes WHERE dispositivo NOT IN ('desktop', 'mobile', 'tablet', 'app')), 'atenção';
