-- ouro.dim_produto: dimensão de produtos (cada formato de um livro é um SKU). Chave: sku.
-- Liga com ouro.fato_vendas pelo sku.

CREATE VIEW ouro.dim_produto AS
SELECT
    sku,
    isbn,
    titulo,
    autor,
    editora,
    categoria,
    formato,
    paginas,
    ano_publicacao,
    preco_capa,
    data_cadastro,
    ativo
FROM prata.produtos;
