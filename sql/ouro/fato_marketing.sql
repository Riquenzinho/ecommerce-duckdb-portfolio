-- ouro.fato_marketing: uma linha por dia + origem/mídia.
-- Chaves para as dimensões: data (dim_calendario), origem_midia (dim_canal_marketing).
-- Linhas sem origem/mídia no Excel ficam com origem_midia vazia (o tráfego é real).

CREATE VIEW ouro.fato_marketing AS
SELECT
    data,
    origem_midia,
    sessoes,
    transacoes,
    receita
FROM prata.marketing;
