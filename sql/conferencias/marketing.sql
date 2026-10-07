-- Conferências de prata.marketing e prata.marketing_depara. Cada linha: (conferencia, quantidade, tipo).

SELECT 'marketing_depara: linha repetida no Excel (fica uma)' AS conferencia,
       (SELECT COUNT(*) FROM bronze.marketing_depara) - (SELECT COUNT(*) FROM prata.marketing_depara) AS quantidade,
       'tratado' AS tipo
UNION ALL
SELECT 'marketing: linha sem origem/mídia no Excel',
       (SELECT COUNT(*) FROM prata.marketing WHERE origem_midia IS NULL), 'atenção'
UNION ALL
SELECT 'marketing: origem/mídia sem canal no de-para (completar a aba DePara)',
       (SELECT COUNT(DISTINCT origem_midia) FROM prata.marketing
        WHERE origem_midia NOT IN (SELECT origem_midia FROM prata.marketing_depara)), 'atenção';
