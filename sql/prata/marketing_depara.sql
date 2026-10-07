-- prata.marketing_depara: de-para origem/mídia -> canal de marketing.
-- Origem: bronze.marketing_depara (dados_origem/marketing.xlsx, aba DePara)
--
-- Regras:
--   - Linhas idênticas repetidas viram uma (DISTINCT).
--   - Se a mesma origem/mídia aparecer com DOIS canais diferentes, a chave primária faz a
--     carga parar: alguém precisa decidir qual é o canal certo no Excel.

CREATE TABLE prata.marketing_depara (
    origem_midia    VARCHAR PRIMARY KEY,
    canal           VARCHAR NOT NULL
);

INSERT INTO prata.marketing_depara
SELECT DISTINCT
    lower(prata.um_espaco("Origem / Mídia"))    AS origem_midia,
    prata.um_espaco("Canal")                    AS canal
FROM bronze.marketing_depara;
