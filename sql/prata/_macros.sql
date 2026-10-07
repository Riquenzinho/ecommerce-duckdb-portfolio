-- Funções de tratamento usadas pelos .sql da prata.
-- O arquivo começa com "_" para rodar antes dos outros. Não cria tabela.
-- As funções ficam gravadas no banco: também podem ser usadas em consultas no DBeaver.

-- Texto: tira os espaços das pontas; texto vazio vira NULL.
CREATE MACRO prata.texto(x) AS NULLIF(TRIM(CAST(x AS VARCHAR)), '');

-- Texto com um espaço só entre as palavras ("Romance  " -> "Romance").
CREATE MACRO prata.um_espaco(x) AS regexp_replace(prata.texto(x), '\s+', ' ', 'g');

-- Só a primeira letra maiúscula ("ENTREGUE", "entregue " -> "Entregue").
CREATE MACRO prata.frase(x) AS upper(left(prata.um_espaco(x), 1)) || lower(substr(prata.um_espaco(x), 2));

-- Número: aceita 49.9, "49,90" e "R$ 1.234,50". O que não for número vira NULL.
CREATE MACRO prata.so_numero(x) AS regexp_replace(CAST(x AS VARCHAR), '[^0-9,.-]', '', 'g');
CREATE MACRO prata.numero(x) AS TRY_CAST(
    CASE WHEN contains(prata.so_numero(x), ',')
         THEN replace(replace(prata.so_numero(x), '.', ''), ',', '.')   -- formato brasileiro
         ELSE prata.so_numero(x) END
    AS DOUBLE);
CREATE MACRO prata.dinheiro(x) AS CAST(ROUND(prata.numero(x), 2) AS DECIMAL(14, 2));
CREATE MACRO prata.inteiro(x) AS CAST(ROUND(prata.numero(x)) AS INTEGER);

-- Código ou identificador: sempre texto, sem o ".0" que o Excel põe em números (100001.0 -> "100001").
CREATE MACRO prata.codigo(x) AS
    CASE WHEN regexp_full_match(prata.texto(x), '[0-9]+(\.0+)?') THEN split_part(prata.texto(x), '.', 1)
         ELSE prata.texto(x) END;

-- CEP: 8 dígitos, com o zero à esquerda que o Excel tirou (1310100 -> "01310100").
CREATE MACRO prata.cep(x) AS lpad(prata.codigo(x), 8, '0');

-- Data: aceita "05/03/2023", "2023-03-05 00:00:00" e o número 20230305.
CREATE MACRO prata.data(x) AS COALESCE(
    TRY_CAST(TRY_STRPTIME(prata.texto(x), '%d/%m/%Y') AS DATE),
    TRY_CAST(TRY_STRPTIME(prata.texto(x), '%Y%m%d') AS DATE),
    TRY_CAST(left(prata.texto(x), 10) AS DATE));

-- Sim/Não, true/false -> texto 'Verdadeiro' / 'Falso' (padrão do projeto, em vez de BOOLEAN).
CREATE MACRO prata.verdadeiro_falso(x) AS
    CASE WHEN lower(prata.texto(x)) IN ('sim', 'true', 'verdadeiro', '1') THEN 'Verdadeiro'
         WHEN lower(prata.texto(x)) IN ('não', 'nao', 'false', 'falso', '0') THEN 'Falso' END;

-- UF: sigla em maiúsculo; nome do estado por extenso vira a sigla ("São Paulo" -> "SP").
CREATE MACRO prata.uf(x) AS
    CASE strip_accents(upper(prata.texto(x)))
        WHEN 'ACRE' THEN 'AC'               WHEN 'ALAGOAS' THEN 'AL'
        WHEN 'AMAPA' THEN 'AP'              WHEN 'AMAZONAS' THEN 'AM'
        WHEN 'BAHIA' THEN 'BA'              WHEN 'CEARA' THEN 'CE'
        WHEN 'DISTRITO FEDERAL' THEN 'DF'   WHEN 'ESPIRITO SANTO' THEN 'ES'
        WHEN 'GOIAS' THEN 'GO'              WHEN 'MARANHAO' THEN 'MA'
        WHEN 'MATO GROSSO' THEN 'MT'        WHEN 'MATO GROSSO DO SUL' THEN 'MS'
        WHEN 'MINAS GERAIS' THEN 'MG'       WHEN 'PARA' THEN 'PA'
        WHEN 'PARAIBA' THEN 'PB'            WHEN 'PARANA' THEN 'PR'
        WHEN 'PERNAMBUCO' THEN 'PE'         WHEN 'PIAUI' THEN 'PI'
        WHEN 'RIO DE JANEIRO' THEN 'RJ'     WHEN 'RIO GRANDE DO NORTE' THEN 'RN'
        WHEN 'RIO GRANDE DO SUL' THEN 'RS'  WHEN 'RONDONIA' THEN 'RO'
        WHEN 'RORAIMA' THEN 'RR'            WHEN 'SANTA CATARINA' THEN 'SC'
        WHEN 'SAO PAULO' THEN 'SP'          WHEN 'SERGIPE' THEN 'SE'
        WHEN 'TOCANTINS' THEN 'TO'
        ELSE upper(prata.texto(x)) END;

-- Acentos corrompidos: desfaz o erro de um texto UTF-8 aberto como Windows-1252
-- ("BalÃ£o" -> "Balão"). Cada par é [quebrado, certo]; chr(n) é um caractere invisível.
-- O list_reduce aplica as trocas uma depois da outra. O texto vai dentro de uma lista ([x])
-- porque, nesta versão do DuckDB, o acumulador precisa ter o mesmo tipo dos pares.
CREATE MACRO prata.corrigir_acentos(x) AS list_reduce([
    ['â€“', '–'], ['â€”', '—'], ['â€˜', '‘'], ['â€™', '’'], ['â€œ', '“'], ['â€' || chr(157), '”'],
    ['Ã¡', 'á'], ['Ã' || chr(160), 'à'], ['Ã¢', 'â'], ['Ã£', 'ã'], ['Ã¤', 'ä'],
    ['Ã©', 'é'], ['Ã¨', 'è'], ['Ãª', 'ê'], ['Ã«', 'ë'],
    ['Ã' || chr(173), 'í'], ['Ã¬', 'ì'], ['Ã®', 'î'], ['Ã¯', 'ï'],
    ['Ã³', 'ó'], ['Ã²', 'ò'], ['Ã´', 'ô'], ['Ãµ', 'õ'], ['Ã¶', 'ö'],
    ['Ãº', 'ú'], ['Ã¹', 'ù'], ['Ã»', 'û'], ['Ã¼', 'ü'], ['Ã§', 'ç'], ['Ã±', 'ñ'],
    ['Ã' || chr(129), 'Á'], ['Ã€', 'À'], ['Ã‚', 'Â'], ['Ãƒ', 'Ã'], ['Ã„', 'Ä'],
    ['Ã‰', 'É'], ['Ãˆ', 'È'], ['ÃŠ', 'Ê'], ['Ã‹', 'Ë'],
    ['Ã' || chr(141), 'Í'], ['ÃŒ', 'Ì'], ['ÃŽ', 'Î'], ['Ã' || chr(143), 'Ï'],
    ['Ã“', 'Ó'], ['Ã’', 'Ò'], ['Ã”', 'Ô'], ['Ã•', 'Õ'], ['Ã–', 'Ö'],
    ['Ãš', 'Ú'], ['Ã™', 'Ù'], ['Ã›', 'Û'], ['Ãœ', 'Ü'], ['Ã‡', 'Ç'], ['Ã‘', 'Ñ'],
    ['Âº', 'º'], ['Âª', 'ª'], ['Â°', '°']
], (texto, troca) -> [replace(texto[1], troca[1], troca[2])], [x])[1];
