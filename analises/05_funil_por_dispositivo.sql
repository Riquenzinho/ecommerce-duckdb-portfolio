-- Pergunta: em qual dispositivo o visitante mais compra? A conversão mudou de um ano para o outro?
--
-- Usa: ouro.fato_sessoes (sessões e pedidos registrados pela ferramenta de análise).
-- Conversão = pedidos / sessões.

SELECT
    year(data)                                          AS ano,
    dispositivo,
    SUM(sessoes)                                        AS sessoes,
    SUM(pedidos)                                        AS pedidos,
    ROUND(SUM(pedidos) / SUM(sessoes) * 100, 2)         AS conversao_pct,
    ROUND(SUM(novos_usuarios) / SUM(usuarios) * 100, 1) AS pct_usuarios_novos,
    ROUND(SUM(sessoes) / SUM(SUM(sessoes)) OVER (PARTITION BY year(data)) * 100, 1) AS pct_das_sessoes
FROM ouro.fato_sessoes
GROUP BY year(data), dispositivo    -- explícito: com GROUP BY ALL o DuckDB se confunde com o OVER
ORDER BY ano, sessoes DESC;
