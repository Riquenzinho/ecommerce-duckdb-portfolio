-- ouro.dim_cliente: dimensão de clientes. Chave: id_cliente.
-- Liga com ouro.fato_vendas e ouro.fato_pedidos pelo id_cliente.
-- Não há cadastro de clientes nos Excel: a dimensão é montada a partir dos pedidos.
-- Endereço = o do pedido mais recente do cliente.

CREATE VIEW ouro.dim_cliente AS
SELECT
    id_cliente,
    arg_max(uf, data_pedido)                AS uf,
    arg_max(cidade, data_pedido)            AS cidade,
    arg_max(cep, data_pedido)               AS cep,
    ouro.regiao(arg_max(uf, data_pedido))   AS regiao,
    MIN(data_pedido)                        AS primeira_compra,
    MAX(data_pedido)                        AS ultima_compra
FROM prata.vendas
GROUP BY id_cliente;
