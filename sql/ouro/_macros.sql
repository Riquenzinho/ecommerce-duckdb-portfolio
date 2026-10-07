-- Regras de negócio do ouro, escritas uma vez só e usadas pelos fatos.
-- O arquivo começa com "_" para rodar antes dos outros. Não cria tabela.

-- Venda válida: pedido que gerou receita. Cancelado, Devolvido e Aguardando pagamento não contam.
CREATE MACRO ouro.venda_valida(status) AS
    CASE WHEN status IN ('Entregue', 'Faturado', 'Em transporte') THEN 'Verdadeiro' ELSE 'Falso' END;

-- Região do Brasil a partir da UF.
CREATE MACRO ouro.regiao(uf) AS
    CASE WHEN uf IN ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') THEN 'Norte'
         WHEN uf IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Nordeste'
         WHEN uf IN ('DF', 'GO', 'MS', 'MT') THEN 'Centro-Oeste'
         WHEN uf IN ('ES', 'MG', 'RJ', 'SP') THEN 'Sudeste'
         WHEN uf IN ('PR', 'RS', 'SC') THEN 'Sul' END;
