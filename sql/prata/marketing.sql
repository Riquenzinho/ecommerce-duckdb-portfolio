-- prata.marketing: sessões, transações e receita por dia + origem/mídia.
-- Origem: bronze.marketing (dados_origem/marketing.xlsx, aba Base)
--
-- Regras:
--   - "google / cpc" é guardado inteiro (origem_midia, para ligar com o de-para) e separado
--     em origem ("google") e midia ("cpc"). Tudo em minúsculo.
--   - Receita arredondada para 2 casas (a ferramenta de análise exporta com 12 casas).
--   - Linhas sem origem/mídia ficam, com origem_midia NULL (o tráfego é real); a
--     conferência mostra quantas são. Por isso a trava é UNIQUE e não chave primária.

CREATE TABLE prata.marketing (
    data            DATE NOT NULL,
    origem_midia    VARCHAR,
    origem          VARCHAR,
    midia           VARCHAR,
    sessoes         INTEGER,
    transacoes      INTEGER,
    receita         DECIMAL(14, 2),
    _linha_excel    INTEGER NOT NULL,
    UNIQUE (data, origem_midia)
);

INSERT INTO prata.marketing
SELECT
    prata.data("Data")                                  AS data,
    lower(prata.um_espaco("Origem / Mídia"))            AS origem_midia,
    prata.texto(split_part(origem_midia, ' / ', 1))     AS origem,
    prata.texto(split_part(origem_midia, ' / ', 2))     AS midia,
    prata.inteiro("Sessões")                            AS sessoes,
    prata.inteiro("Transações")                         AS transacoes,
    prata.dinheiro("Receita")                           AS receita,
    CAST("_linha_excel" AS INTEGER)                     AS _linha_excel
FROM (SELECT COLUMNS(*)::VARCHAR FROM bronze.marketing);
