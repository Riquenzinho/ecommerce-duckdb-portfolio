-- Conferências de prata.vendas. Cada linha: (conferencia, quantidade, tipo).
--   tipo 'tratado' = sujeira conhecida que a prata resolve sozinha (mostra quanto tratou)
--   tipo 'atenção' = precisa de alguém (o certo é 0)

WITH itens_excel AS (
    SELECT "Pedido", "Item", "Produto", "Valor Item" FROM bronze.vendas_2023
    UNION ALL SELECT "Pedido", "Item", "Produto", "Valor Item" FROM bronze.vendas_2024
    UNION ALL SELECT "Pedido", "Item", "Produto", "Valor Item" FROM bronze.vendas_2025
),
itens_excel_sem_repeticao AS (
    SELECT DISTINCT ON ("Pedido", "Item") * FROM itens_excel
)
SELECT 'vendas: pedido + item repetido no Excel (fica a primeira linha)' AS conferencia,
       (SELECT COUNT(*) FROM itens_excel) - (SELECT COUNT(*) FROM prata.vendas) AS quantidade, 'tratado' AS tipo
UNION ALL
SELECT 'vendas: título com acento corrompido no Excel (corrigido)',
       (SELECT COUNT(*) FROM itens_excel WHERE "Produto" LIKE '%Ã%' OR "Produto" LIKE '%â€%'), 'tratado'
UNION ALL
SELECT 'vendas: status escrito fora do padrão no Excel (padronizado)',
       (SELECT COUNT(*) FROM (SELECT "Status" FROM bronze.vendas_2023 UNION ALL SELECT "Status" FROM bronze.vendas_2024
                              UNION ALL SELECT "Status" FROM bronze.vendas_2025)
        WHERE "Status" <> prata.frase("Status")), 'tratado'
UNION ALL
SELECT 'vendas: título ainda com acento corrompido',
       (SELECT COUNT(*) FROM prata.vendas WHERE produto LIKE '%Ã%' OR produto LIKE '%â€%'), 'atenção'
UNION ALL
SELECT 'vendas: status fora da lista conhecida',
       (SELECT COUNT(*) FROM prata.vendas WHERE status NOT IN
            ('Entregue', 'Cancelado', 'Devolvido', 'Faturado', 'Em transporte', 'Aguardando pagamento')), 'atenção'
UNION ALL
SELECT 'vendas: UF que não é sigla de estado',
       (SELECT COUNT(*) FROM prata.vendas WHERE uf NOT IN
            ('AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA',
             'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO')), 'atenção'
UNION ALL
SELECT 'vendas: SKU vendido que não está no catálogo',
       (SELECT COUNT(DISTINCT sku) FROM prata.vendas WHERE sku NOT IN (SELECT sku FROM prata.produtos)), 'atenção'
UNION ALL
SELECT 'vendas: soma de valor_item diferente do Excel',
       (SELECT CASE WHEN abs((SELECT SUM(valor_item) FROM prata.vendas)
                             - (SELECT SUM(prata.dinheiro("Valor Item")) FROM itens_excel_sem_repeticao)) > 0.01
                    THEN 1 ELSE 0 END), 'atenção';
