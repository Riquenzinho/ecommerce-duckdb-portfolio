-- ouro.fato_sessoes: uma linha por dia + dispositivo (desktop, mobile, tablet, app).
-- Chave para a dimensão: data (dim_calendario).
-- pedidos e receita são os que a ferramenta de análise registrou (um pouco menos que as
-- vendas reais); para receita oficial use ouro.fato_vendas / ouro.fato_pedidos.

CREATE VIEW ouro.fato_sessoes AS
SELECT
    data,
    dispositivo,
    sessoes,
    usuarios,
    novos_usuarios,
    pedidos,
    receita
FROM prata.sessoes;
