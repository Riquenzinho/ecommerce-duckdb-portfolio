"""
Lista das bases que a carga lê.

Cada linha: tabela do bronze -> (arquivo dentro de dados_origem, aba, linha do cabeçalho).
Para acrescentar uma base, basta uma linha nova aqui (e o .sql dela na prata e no ouro).
Nome da tabela: só minúsculas, números e "_".
"""

BASES = {
    "vendas_2023":      ("vendas/vendas_2023.xlsx", "Pedidos", 1),
    "vendas_2024":      ("vendas/vendas_2024.xlsx", "Pedidos", 1),
    "vendas_2025":      ("vendas/vendas_2025.xlsx", "Pedidos", 1),
    "produtos":         ("produtos.xlsx", "Catalogo", 3),     # 2 linhas de título antes do cabeçalho
    "sessoes":          ("sessoes.xlsx", "Sessoes", 1),
    "marketing":        ("marketing.xlsx", "Base", 1),
    "marketing_depara": ("marketing.xlsx", "DePara", 1),
    "metas":            ("metas.xlsx", "Metas", 1),
}
