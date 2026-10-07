-- ouro.dim_canal_marketing: dimensão de origem/mídia e canal de marketing. Chave: origem_midia.
-- Liga com ouro.fato_marketing, ouro.fato_vendas e ouro.fato_pedidos pelo origem_midia.
-- Junta todas as origens/mídias que aparecem no marketing, nas vendas e no de-para.
-- Origem que não está no de-para fica com canal 'Sem canal no de-para' (em vez de sumir);
-- a conferência avisa para completar a aba DePara do marketing.xlsx.

CREATE VIEW ouro.dim_canal_marketing AS
WITH todas AS (
    SELECT origem_midia FROM prata.marketing WHERE origem_midia IS NOT NULL
    UNION
    SELECT origem || ' / ' || midia FROM prata.vendas WHERE origem IS NOT NULL
    UNION
    SELECT origem_midia FROM prata.marketing_depara
)
SELECT
    t.origem_midia,
    split_part(t.origem_midia, ' / ', 1)        AS origem,
    split_part(t.origem_midia, ' / ', 2)        AS midia,
    COALESCE(d.canal, 'Sem canal no de-para')   AS canal
FROM todas AS t
LEFT JOIN prata.marketing_depara AS d USING (origem_midia);
