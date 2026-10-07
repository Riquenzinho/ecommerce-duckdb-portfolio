-- ouro.dim_calendario: dimensão de datas. Chave: data.
-- Liga com a data de todos os fatos. Os tratamentos estão em sql/prata/calendario.sql.

CREATE VIEW ouro.dim_calendario AS
SELECT
    data,
    ano,
    trimestre,
    ano_trimestre,
    mes,
    nome_mes,
    ano_mes,
    inicio_mes,
    dia,
    dia_semana,
    nome_dia,
    semana_iso,
    fim_de_semana,
    feriado,
    nome_feriado,
    dia_util,
    dia_util_do_mes,
    data_comercial
FROM prata.calendario;
