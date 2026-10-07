-- Conferências de prata.produtos. Cada linha: (conferencia, quantidade, tipo).

SELECT 'produtos: SKU repetido no Excel (fica a linha mais embaixo)' AS conferencia,
       (SELECT COUNT(*) FROM bronze.produtos) - (SELECT COUNT(*) FROM prata.produtos) AS quantidade,
       'tratado' AS tipo
UNION ALL
SELECT 'produtos: categoria escrita fora do padrão no Excel (padronizada)',
       (SELECT COUNT(*) FROM bronze.produtos WHERE "Categoria" <> prata.frase("Categoria")), 'tratado'
UNION ALL
SELECT 'produtos: ativo diferente de Verdadeiro/Falso',
       (SELECT COUNT(*) FROM prata.produtos WHERE ativo NOT IN ('Verdadeiro', 'Falso')), 'atenção';
