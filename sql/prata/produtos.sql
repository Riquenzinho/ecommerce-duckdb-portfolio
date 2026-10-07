-- prata.produtos: cadastro de livros, uma linha por SKU (cada formato de um livro é um SKU).
-- Origem: bronze.produtos (dados_origem/produtos.xlsx, aba Catalogo, cabeçalho na linha 3)
--
-- Regras:
--   - SKU repetido no Excel: fica a linha mais embaixo, que é a atualizada (preço novo).
--   - Categoria numa grafia só ("ROMANCE", "Romance " -> "Romance").
--   - SKU e ISBN são texto (identificadores, não números para somar).
--   - ativo: texto 'Verdadeiro' / 'Falso' (no Excel, Sim / Não).

CREATE TABLE prata.produtos (
    sku             VARCHAR PRIMARY KEY,
    isbn            VARCHAR NOT NULL,
    titulo          VARCHAR NOT NULL,
    autor           VARCHAR,
    editora         VARCHAR,
    categoria       VARCHAR NOT NULL,
    formato         VARCHAR NOT NULL,
    paginas         INTEGER,
    ano_publicacao  INTEGER,
    preco_capa      DECIMAL(14, 2),
    data_cadastro   DATE,
    ativo           VARCHAR NOT NULL,
    _linha_excel    INTEGER NOT NULL
);

INSERT INTO prata.produtos
SELECT
    prata.codigo("SKU")                 AS sku,
    prata.codigo("ISBN")                AS isbn,
    prata.um_espaco("Título")           AS titulo,
    prata.um_espaco("Autor")            AS autor,
    prata.um_espaco("Editora")          AS editora,
    prata.frase("Categoria")            AS categoria,
    prata.frase("Formato")              AS formato,
    prata.inteiro("Páginas")            AS paginas,
    prata.inteiro("Ano de Publicação")  AS ano_publicacao,
    prata.dinheiro("Preço de Capa")     AS preco_capa,
    prata.data("Data de Cadastro")      AS data_cadastro,
    prata.verdadeiro_falso("Ativo")     AS ativo,
    CAST("_linha_excel" AS INTEGER)     AS _linha_excel
FROM (SELECT COLUMNS(*)::VARCHAR FROM bronze.produtos)
QUALIFY row_number() OVER (PARTITION BY prata.codigo("SKU") ORDER BY CAST("_linha_excel" AS INTEGER) DESC) = 1;
