-- prata.calendario: uma linha por dia, de 01/01/2023 até 31/12 do ano em que a carga roda.
-- Não vem de Excel: é gerado aqui. Quando o ano virar, a primeira carga acrescenta o ano novo.
--
-- Regras:
--   - Semana ISO: começa na segunda (dia_semana 1 = segunda, 7 = domingo).
--   - Feriados nacionais do Brasil no calendário bancário (inclui Carnaval e Corpus Christi;
--     Consciência Negra a partir de 2024). Os móveis são calculados a partir da Páscoa.
--   - dia_util = segunda a sexta que não é feriado.
--   - fim_de_semana, feriado e dia_util são texto 'Verdadeiro' / 'Falso' (padrão do projeto).
--   - Para acrescentar um feriado ou data comercial de dia fixo: uma linha na lista VALUES.

CREATE TABLE prata.calendario (
    data            DATE PRIMARY KEY,
    ano             INTEGER NOT NULL,
    trimestre       INTEGER NOT NULL,
    ano_trimestre   VARCHAR NOT NULL,   -- 2025-T4
    mes             INTEGER NOT NULL,
    nome_mes        VARCHAR NOT NULL,
    ano_mes         VARCHAR NOT NULL,   -- 2025-11
    inicio_mes      DATE NOT NULL,
    dia             INTEGER NOT NULL,
    dia_semana      INTEGER NOT NULL,
    nome_dia        VARCHAR NOT NULL,
    semana_iso      INTEGER NOT NULL,
    fim_de_semana   VARCHAR NOT NULL,
    feriado         VARCHAR NOT NULL,
    nome_feriado    VARCHAR,
    dia_util        VARCHAR NOT NULL,
    dia_util_do_mes INTEGER,            -- 1º, 2º, 3º... dia útil do mês (vazio se não for dia útil)
    data_comercial  VARCHAR             -- Black Friday, Dia das Mães, Dia do Livro...
);

INSERT INTO prata.calendario
WITH dias AS (
    SELECT CAST(range AS DATE) AS data
    FROM range(DATE '2023-01-01', make_date(year(current_date), 12, 31) + INTERVAL 1 DAY, INTERVAL 1 DAY)
),
anos AS (
    SELECT DISTINCT CAST(year(data) AS INTEGER) AS ano FROM dias
),
-- Domingo de Páscoa (algoritmo de Meeus/Jones/Butcher, calendário gregoriano)
pascoa AS (
    SELECT ano,
           ano % 19 AS a, ano // 100 AS b, ano % 100 AS c, b // 4 AS d, b % 4 AS e,
           (b + 8) // 25 AS f, (b - f + 1) // 3 AS g, (19 * a + b - d - g + 15) % 30 AS h,
           c // 4 AS i, c % 4 AS k, (32 + 2 * e + 2 * i - h - k) % 7 AS l,
           (a + 11 * h + 22 * l) // 451 AS m,
           make_date(ano, (h + l - 7 * m + 114) // 31, (h + l - 7 * m + 114) % 31 + 1) AS domingo
    FROM anos
),
feriados AS (
    SELECT make_date(ano, mes, dia) AS data, nome
    FROM anos, (VALUES
        (1, 1, 'Confraternização Universal', 2000), (4, 21, 'Tiradentes', 2000),
        (5, 1, 'Dia do Trabalho', 2000), (9, 7, 'Independência do Brasil', 2000),
        (10, 12, 'Nossa Senhora Aparecida', 2000), (11, 2, 'Finados', 2000),
        (11, 15, 'Proclamação da República', 2000), (11, 20, 'Dia da Consciência Negra', 2024),
        (12, 25, 'Natal', 2000)
    ) AS fixos(mes, dia, nome, desde)
    WHERE ano >= desde
    UNION ALL
    SELECT domingo + dias_da_pascoa, nome
    FROM pascoa, (VALUES
        (-48, 'Carnaval (segunda-feira)'), (-47, 'Carnaval (terça-feira)'),
        (-2, 'Sexta-feira Santa'), (60, 'Corpus Christi')
    ) AS moveis(dias_da_pascoa, nome)
),
datas_comerciais AS (
    SELECT make_date(ano, mes, dia) AS data, nome
    FROM anos, (VALUES
        (3, 15, 'Dia do Consumidor'), (4, 23, 'Dia Mundial do Livro'), (6, 12, 'Dia dos Namorados'),
        (10, 12, 'Dia das Crianças'), (10, 29, 'Dia Nacional do Livro'), (12, 25, 'Natal')
    ) AS fixas(mes, dia, nome)
    UNION ALL SELECT domingo, 'Páscoa' FROM pascoa
    -- 2º domingo de maio e de agosto; Black Friday = 4ª sexta de novembro
    UNION ALL SELECT make_date(ano, 5, 1) + CAST((7 - isodow(make_date(ano, 5, 1))) % 7 AS INTEGER) + 7,
                     'Dia das Mães' FROM anos
    UNION ALL SELECT make_date(ano, 8, 1) + CAST((7 - isodow(make_date(ano, 8, 1))) % 7 AS INTEGER) + 7,
                     'Dia dos Pais' FROM anos
    UNION ALL SELECT make_date(ano, 11, 1) + CAST((12 - isodow(make_date(ano, 11, 1))) % 7 AS INTEGER) + 21,
                     'Black Friday' FROM anos
    UNION ALL SELECT make_date(ano, 11, 1) + CAST((12 - isodow(make_date(ano, 11, 1))) % 7 AS INTEGER) + 24,
                     'Cyber Monday' FROM anos
),
base AS (
    SELECT
        d.data,
        CAST(isodow(d.data) AS INTEGER) AS dia_semana,
        f.nome_feriado,
        isodow(d.data) <= 5 AND f.nome_feriado IS NULL AS e_dia_util,
        c.data_comercial
    FROM dias AS d
    LEFT JOIN (SELECT data, string_agg(nome, ' / ' ORDER BY nome) AS nome_feriado
               FROM feriados GROUP BY data) AS f USING (data)
    LEFT JOIN (SELECT data, string_agg(nome, ' / ' ORDER BY nome) AS data_comercial
               FROM datas_comerciais GROUP BY data) AS c USING (data)
)
SELECT
    data,
    year(data)                                              AS ano,
    quarter(data)                                           AS trimestre,
    strftime(data, '%Y') || '-T' || quarter(data)           AS ano_trimestre,
    month(data)                                             AS mes,
    ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto',
     'Setembro', 'Outubro', 'Novembro', 'Dezembro'][month(data)] AS nome_mes,
    strftime(data, '%Y-%m')                                 AS ano_mes,
    CAST(date_trunc('month', data) AS DATE)                 AS inicio_mes,
    day(data)                                               AS dia,
    dia_semana,
    ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira',
     'Sábado', 'Domingo'][dia_semana]                       AS nome_dia,
    weekofyear(data)                                        AS semana_iso,
    CASE WHEN dia_semana >= 6 THEN 'Verdadeiro' ELSE 'Falso' END        AS fim_de_semana,
    CASE WHEN nome_feriado IS NOT NULL THEN 'Verdadeiro' ELSE 'Falso' END AS feriado,
    nome_feriado,
    CASE WHEN e_dia_util THEN 'Verdadeiro' ELSE 'Falso' END             AS dia_util,
    CASE WHEN e_dia_util THEN
        SUM(CAST(e_dia_util AS INTEGER)) OVER (PARTITION BY date_trunc('month', data) ORDER BY data)
    END                                                     AS dia_util_do_mes,
    data_comercial
FROM base
ORDER BY data;
