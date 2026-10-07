"""
Gera os arquivos Excel de origem da Livraria Capítulo Um, uma livraria online FICTÍCIA.

Tudo é inventado por este script: livros, autores, editoras, clientes e números. Qualquer
semelhança com empresas, obras ou pessoas reais é coincidência. Não há dados pessoais:
o cliente é só um número (ID Cliente).

A SEMENTE faz o script gerar sempre os mesmos dados, em qualquer computador.

Os arquivos saem com "sujeira" de propósito, a mesma que aparece em exportações reais,
para que as camadas prata e ouro mostrem como tratá-la:

  vendas_2023.xlsx   datas gravadas como texto ("05/03/2023"); preço às vezes como texto
                     ("R$ 49,90"); coluna "Obs Interna", que deixou de existir; sem as
                     colunas "Canal" e "Tipo de Entrega", que só surgiram em 2024
  vendas_2024.xlsx   acentos corrompidos em parte dos títulos ("CoraÃ§Ã£o"); os pedidos
                     de um dia (11/03/2024) colados duas vezes
  vendas_2025.xlsx   "Forma de Pagamento" passou a se chamar "Pagamento"; coluna nova
                     "Avaliação"
  todos os anos      status com grafias diferentes ("Entregue", "ENTREGUE", "entregue ");
                     UF às vezes por extenso ("São Paulo"); CEP como número (perde o zero
                     à esquerda: 01310-100 vira 1310100); frete e total do PEDIDO repetidos
                     em cada linha de item (somar essas colunas dá valor errado)
  produtos.xlsx      2 linhas de título antes do cabeçalho; SKUs repetidos (a linha mais
                     embaixo é a atualizada); categoria com maiúsculas e espaços diferentes
  sessoes.xlsx       data como número (20230105); dispositivo com grafias diferentes;
                     dias com o desktop repetido; linha "Total" no fim
  marketing.xlsx     linhas sem origem/mídia; receita com muitas casas decimais; o de-para
                     (aba DePara) com uma linha repetida e uma origem sem canal
  metas.xlsx         falta o dia 29/02/2024

Uso:  python gerar_dados.py
"""
import datetime as dt
import time
from pathlib import Path

import numpy as np
import pandas as pd
from openpyxl import Workbook
from openpyxl.cell import WriteOnlyCell

SEMENTE = 42
PASTA = Path(__file__).parent / "dados_origem"
INICIO, FIM = dt.date(2023, 1, 1), dt.date(2025, 12, 31)
PEDIDOS_POR_DIA = 150        # média de pedidos por dia no começo de 2023
CRESCIMENTO_ANUAL = 0.16     # a loja cresce 16% ao ano
REAJUSTE_ANUAL = 0.07        # os preços sobem 7% ao ano
N_OBRAS = 1800               # livros diferentes (cada um pode ter mais de um formato)
N_CLIENTES = 180_000         # clientes possíveis; cada um "nasce" na primeira compra
CHANCE_DE_VOLTAR = (2, 3)    # cada cliente tem a sua chance de comprar de novo (Beta(2,3): média 40%)
DIAS_ATE_VOLTAR = 90         # quem volta, volta em média 3 meses depois (mínimo de 7 dias)

rng = np.random.default_rng(SEMENTE)
DIAS = [INICIO + dt.timedelta(n) for n in range((FIM - INICIO).days + 1)]

# ---------------------------------------------------------------------------------------
# Listas usadas para inventar os dados
# ---------------------------------------------------------------------------------------

# categoria: (peso no catálogo, páginas mín., páginas máx., preço base da capa comum)
CATEGORIAS = {
    "Romance": (14, 160, 520, 54.9),
    "Fantasia": (9, 250, 800, 69.9),
    "Suspense": (9, 200, 480, 59.9),
    "Ficção científica": (5, 200, 600, 64.9),
    "Juvenil": (8, 150, 400, 49.9),
    "Infantil": (10, 24, 64, 39.9),
    "Autoajuda": (8, 120, 300, 44.9),
    "Negócios": (7, 160, 380, 69.9),
    "Biografia": (5, 200, 600, 74.9),
    "História": (5, 250, 700, 79.9),
    "Didático": (6, 120, 400, 89.9),
    "Quadrinhos": (6, 48, 220, 49.9),
    "Culinária": (4, 120, 320, 79.9),
    "Tecnologia": (4, 200, 600, 99.9),
}
SO_IMPRESSO = {"Infantil", "Didático", "Quadrinhos", "Culinária"}

TITULO_FICCAO = (
    ["O Silêncio", "A Casa", "O Último Verão", "As Cartas", "O Jardim", "A Ilha", "O Segredo",
     "A Herança", "O Mapa", "A Travessia", "Os Dias", "A Memória", "O Farol", "A Noite",
     "O Caderno", "A Estrada", "O Relógio", "A Biblioteca", "O Inventário", "A Cidade",
     "O Voo", "A Promessa", "O Labirinto", "A Fronteira"],
    ["das Marés", "de Vidro", "do Norte", "de Papel", "das Horas", "do Rio", "de Inverno",
     "dos Sonhos", "da Serra", "sem Nome", "de Sal", "das Sombras", "do Tempo", "de Outono",
     "do Esquecimento", "dos Invisíveis", "do Avô", "de Areia", "das Coisas Perdidas",
     "do Fim do Mundo"],
)
TITULO_TEMAS = {   # categoria: (temas, modelos de título)
    "Autoajuda": (["Hábitos", "Foco", "Coragem", "Calma", "Gratidão", "Disciplina", "Recomeços", "Escolhas"],
                  ["{t}: um guia prático", "{t} sem complicação", "{t} em 30 dias", "Pequeno manual de {t}"]),
    "Negócios": (["Vendas", "Liderança", "Finanças Pessoais", "Gestão de Equipes", "Marketing Digital",
                  "Empreendedorismo", "Negociação", "Produtividade"],
                 ["{t} na Prática", "O Essencial de {t}", "{t} para Iniciantes", "{t}: do zero ao avançado"]),
    "História": (["do Café no Brasil", "das Ferrovias", "do Rádio", "da Imprensa", "do Futebol",
                  "das Cidades", "dos Correios", "da Música Popular"],
                 ["Uma História {t}", "Breve História {t}", "Os Anos de Ouro {t}"]),
    "Tecnologia": (["Python", "SQL", "Excel", "Análise de Dados", "Power BI", "Redes de Computadores",
                    "Estatística", "Machine Learning", "Git"],
                   ["{t} na Prática", "Aprenda {t}", "{t} para Iniciantes", "Guia Completo de {t}"]),
    "Culinária": (["Cozinha de Vó", "Pães em Casa", "Receitas de 15 Minutos", "Doces de Festa",
                   "Cozinha Vegetariana", "Churrasco sem Segredo", "Marmitas da Semana"],
                  ["{t}", "{t}: edição ilustrada", "Mais {t}"]),
}
BICHOS = ["O Tatu", "A Coruja", "O Jacaré", "A Tartaruga", "O Sapo", "A Girafa", "O Pinguim",
          "A Formiga", "O Leão", "A Baleia"]
OBJETOS = ["a Lua Amarela", "o Guarda-chuva", "a Bicicleta Nova", "o Chapéu Perdido",
           "a Estrela Cadente", "o Balão Vermelho", "a Caixa de Lápis", "o Trem da Manhã"]
MATERIAS = ["Matemática", "Português", "Ciências", "Geografia", "História", "Inglês", "Física", "Química"]
SERIES = ["6º ano", "7º ano", "8º ano", "9º ano", "Ensino Médio vol. 1", "Ensino Médio vol. 2", "Vestibular"]
HEROIS = ["Capitã Ventania", "Os Guardiões do Cerrado", "Zé Faísca", "Liga Noturna", "Patrulha do Mangue",
          "Agente Garoa"]
SUBTITULO_BIOGRAFIA = ["uma vida", "memórias", "a trajetória", "entre dois mundos", "o começo de tudo"]

NOMES = ["Ana", "Bruno", "Carla", "Daniel", "Elisa", "Fábio", "Gabriela", "Heitor", "Isabela", "João",
         "Larissa", "Marcelo", "Natália", "Otávio", "Paula", "Rafael", "Sofia", "Tiago", "Vera", "Yuri",
         "Beatriz", "Caio", "Débora", "Eduardo", "Flávia", "Gustavo", "Helena", "Igor", "Júlia", "Lucas",
         "Marina", "Nelson", "Olívia", "Pedro", "Renata", "Sérgio", "Teresa", "Vinícius", "Clara", "André"]
SOBRENOMES = ["Albuquerque", "Barros", "Campos", "Duarte", "Esteves", "Ferraz", "Guimarães", "Holanda",
              "Ibrahim", "Jardim", "Lacerda", "Macedo", "Nogueira", "Orsini", "Pacheco", "Queiroz",
              "Rezende", "Salgado", "Tavares", "Uchoa", "Valente", "Werneck", "Xavier", "Zanetti",
              "Amaral", "Bastos", "Coutinho", "Dornelles", "Falcão", "Garcez"]
EDITORAS = ["Edições Ventania", "Editora Horizonte Raso", "Casa Tinteiro", "Editora Pé de Página",
            "Edições Andarilho", "Editora Folha Solta", "Selo Cais", "Editora Trilha Curta",
            "Edições Candeia Nova", "Editora Rodapé", "Selo Margem Larga", "Editora Sextante Azul"]

# (UF, cidade, faixa dos 2 primeiros dígitos do CEP, peso)
LOCAIS = [
    ("SP", "São Paulo", (1, 5), 18), ("SP", "Campinas", (13, 13), 4), ("SP", "Santos", (11, 11), 2),
    ("SP", "Ribeirão Preto", (14, 14), 2), ("RJ", "Rio de Janeiro", (20, 23), 9),
    ("RJ", "Niterói", (24, 24), 2), ("MG", "Belo Horizonte", (30, 31), 6), ("MG", "Uberlândia", (38, 38), 2),
    ("PR", "Curitiba", (80, 82), 4), ("PR", "Londrina", (86, 86), 1), ("RS", "Porto Alegre", (90, 91), 4),
    ("SC", "Florianópolis", (88, 88), 3), ("SC", "Joinville", (89, 89), 1), ("BA", "Salvador", (40, 42), 4),
    ("DF", "Brasília", (70, 72), 4), ("GO", "Goiânia", (74, 74), 2), ("PE", "Recife", (50, 52), 3),
    ("CE", "Fortaleza", (60, 61), 3), ("ES", "Vitória", (29, 29), 1), ("PA", "Belém", (66, 66), 1),
    ("AM", "Manaus", (69, 69), 1), ("MT", "Cuiabá", (78, 78), 1), ("MS", "Campo Grande", (79, 79), 1),
    ("PB", "João Pessoa", (58, 58), 1), ("RN", "Natal", (59, 59), 1),
]
NOME_DA_UF = {"SP": "São Paulo", "RJ": "Rio de Janeiro", "MG": "Minas Gerais", "PR": "Paraná",
              "RS": "Rio Grande do Sul", "SC": "Santa Catarina", "BA": "Bahia", "DF": "Distrito Federal",
              "GO": "Goiás", "PE": "Pernambuco", "CE": "Ceará", "ES": "Espírito Santo", "PA": "Pará",
              "AM": "Amazonas", "MT": "Mato Grosso", "MS": "Mato Grosso do Sul", "PB": "Paraíba",
              "RN": "Rio Grande do Norte"}
FRETE_BARATO = {"SP", "RJ", "MG", "ES", "PR", "SC", "RS"}   # Sudeste e Sul

# origem, mídia: (peso, ano em que começou)
ORIGENS = {
    ("google", "cpc"): (26, 2023), ("google", "organic"): (20, 2023), ("(direct)", "(none)"): (15, 2023),
    ("instagram", "social"): (9, 2023), ("facebook", "cpc"): (6, 2023), ("newsletter", "email"): (8, 2023),
    ("parceiro_blog", "affiliate"): (4, 2023), ("bing", "organic"): (2, 2023),
    ("youtube", "social"): (2, 2023), ("tiktok", "social"): (4, 2024), ("chatgpt.com", "referral"): (3, 2025),
}
CANAL_MKT = {   # de-para origem / mídia -> canal (chatgpt.com / referral fica de fora de propósito)
    "google / cpc": "Mídia paga", "facebook / cpc": "Mídia paga", "google / organic": "Orgânico",
    "bing / organic": "Orgânico", "(direct) / (none)": "Direto", "instagram / social": "Social",
    "tiktok / social": "Social", "youtube / social": "Social", "pinterest / social": "Social",
    "newsletter / email": "E-mail", "parceiro_blog / affiliate": "Afiliados",
}
CONVERSAO_ORIGEM = {"cpc": 0.015, "organic": 0.012, "(none)": 0.025, "social": 0.006, "email": 0.03,
                    "affiliate": 0.02, "referral": 0.018}

PAGAMENTOS = ["Cartão de crédito", "Pix", "Boleto"]
PESO_PAGAMENTO = {2023: [0.58, 0.30, 0.12], 2024: [0.55, 0.36, 0.09], 2025: [0.52, 0.42, 0.06]}
PARTE_APP = {2023: 0.30, 2024: 0.38, 2025: 0.45}            # pedidos feitos pelo aplicativo
DISPOSITIVO_SITE = {2023: [0.45, 0.48, 0.07], 2024: [0.40, 0.53, 0.07], 2025: [0.36, 0.58, 0.06]}
CONVERSAO_DISPOSITIVO = {"desktop": 0.021, "mobile": 0.011, "tablet": 0.009, "app": 0.028}
CUPONS = {"LEITURA10": 0.10, "BEMVINDO": 0.10, "FRETEGRATIS": 0.0, "BLACKLIVROS": 0.25,
          "VOLTAASAULAS": 0.10, "NATAL15": 0.15, "LIVRO20": 0.20}
OBSERVACOES = ["cliente pediu embrulho para presente", "confirmar número do endereço",
               "pedido com cartão de mensagem", "ligar antes de entregar"]


def escolher(itens, pesos, n=None):
    pesos = np.asarray(pesos, float)
    return rng.choice(itens, size=n, p=pesos / pesos.sum())


def preco_redondo(valor):
    """Preço de livraria: termina em ,90 (ex.: 54,90)."""
    return np.floor(valor) + 0.90


def black_friday(ano):
    """Quarta sexta-feira de novembro."""
    primeiro = dt.date(ano, 11, 1)
    return primeiro + dt.timedelta((4 - primeiro.weekday()) % 7 + 21)


# ---------------------------------------------------------------------------------------
# Catálogo de livros
# ---------------------------------------------------------------------------------------

def inventar_titulo(categoria):
    if categoria in TITULO_TEMAS:
        temas, modelos = TITULO_TEMAS[categoria]
        return str(rng.choice(modelos)).format(t=rng.choice(temas))
    if categoria == "Infantil":
        return f"{rng.choice(BICHOS)} e {rng.choice(OBJETOS)}"
    if categoria == "Didático":
        return f"{rng.choice(MATERIAS)} – {rng.choice(SERIES)}"
    if categoria == "Quadrinhos":
        return f"{rng.choice(HEROIS)} – Volume {rng.integers(1, 13)}"
    if categoria == "Biografia":
        return f"{rng.choice(NOMES)} {rng.choice(SOBRENOMES)}: {rng.choice(SUBTITULO_BIOGRAFIA)}"
    return f"{rng.choice(TITULO_FICCAO[0])} {rng.choice(TITULO_FICCAO[1])}"


def isbn13(quantidade):
    """ISBNs de 13 dígitos (978-65 + 7 dígitos + dígito verificador calculado)."""
    resultado = []
    for numero in rng.choice(10**7, size=quantidade, replace=False):
        corpo = f"97865{numero:07d}"
        soma = sum(int(c) * (1 if i % 2 == 0 else 3) for i, c in enumerate(corpo))
        resultado.append(int(corpo + str((10 - soma % 10) % 10)))
    return resultado


def gerar_catalogo():
    combinacoes = rng.choice(len(NOMES) * len(SOBRENOMES), size=700, replace=False)
    autores = [f"{NOMES[c // len(SOBRENOMES)]} {SOBRENOMES[c % len(SOBRENOMES)]}" for c in combinacoes]
    peso_autor = rng.pareto(1.5, len(autores)) + 1           # poucos autores escrevem muitos livros

    nomes_cat = list(CATEGORIAS)
    anos = np.arange(1995, 2026)
    linhas = []
    for categoria in escolher(nomes_cat, [CATEGORIAS[c][0] for c in nomes_cat], N_OBRAS):
        categoria = str(categoria)
        _, pag_min, pag_max, preco_base = CATEGORIAS[categoria]
        ano = int(escolher(anos, 1.12 ** (anos - 1995)))
        if ano >= INICIO.year:                                # lançamento: cadastrado no ano em que saiu
            limite = min((FIM - dt.date(ano, 1, 1)).days, 364)
            cadastro = dt.date(ano, 1, 1) + dt.timedelta(int(rng.integers(0, limite + 1)))
        else:
            cadastro = dt.date(2015, 1, 1) + dt.timedelta(int(rng.integers(0, 2921)))
        titulo = inventar_titulo(categoria) + (" – 2ª edição" if rng.random() < 0.08 else "")
        autor = "Equipe Editorial" if categoria == "Didático" else str(escolher(autores, peso_autor))
        editora = str(rng.choice(EDITORAS))
        paginas = int(rng.integers(pag_min, pag_max + 1))
        base = preco_base * rng.lognormal(0, 0.22)
        popularidade = rng.lognormal(0, 1.4)
        ativo = "Não" if rng.random() < (0.35 if ano < 2010 else 0.03) else "Sim"

        formatos = [("Capa comum", base, 1.0)]
        if rng.random() < (0.40 if categoria == "Infantil" else 0.15):
            formatos.append(("Capa dura", base * 1.35, 0.25))
        if categoria not in SO_IMPRESSO and rng.random() < 0.60:
            formatos.append(("E-book", base * 0.55, 0.35))
        for formato, preco, parte in formatos:
            linhas.append({"Título": titulo, "Autor": autor, "Editora": editora, "Categoria": categoria,
                           "Formato": formato, "Páginas": paginas, "Ano de Publicação": ano,
                           "Preço de Capa": preco_redondo(preco), "Data de Cadastro": cadastro,
                           "Ativo": ativo, "_popularidade": popularidade * parte})

    produtos = pd.DataFrame(linhas).sample(frac=1, random_state=SEMENTE).reset_index(drop=True)
    produtos.insert(0, "SKU", np.arange(100001, 100001 + len(produtos)))
    produtos.insert(1, "ISBN", isbn13(len(produtos)))
    return produtos


# ---------------------------------------------------------------------------------------
# Clientes (só número e endereço de entrega: cidade, UF e CEP)
# ---------------------------------------------------------------------------------------

def gerar_clientes():
    local = escolher(len(LOCAIS), [l[3] for l in LOCAIS], N_CLIENTES)
    faixa = np.array([LOCAIS[i][2] for i in local])
    prefixo = rng.integers(faixa[:, 0], faixa[:, 1] + 1)
    return pd.DataFrame({
        "ID Cliente": np.arange(500001, 500001 + N_CLIENTES),
        "UF": [LOCAIS[i][0] for i in local],
        "Cidade": [LOCAIS[i][1] for i in local],
        "CEP": prefixo * 1_000_000 + rng.integers(0, 1_000_000, N_CLIENTES),   # número: perde o zero
        "_chance_de_voltar": rng.beta(*CHANCE_DE_VOLTAR, N_CLIENTES),        # alguns são bem fiéis
    })


# ---------------------------------------------------------------------------------------
# Vendas: um dia de cada vez
# ---------------------------------------------------------------------------------------

def fator_do_dia(d):
    """Quanto o dia vende em relação a um dia comum."""
    fator = [1.10, 1.05, 1.0, 1.0, 0.95, 0.80, 0.90][d.weekday()]
    fator *= {1: 0.90, 2: 1.15, 3: 1.0, 4: 0.95, 5: 1.0, 6: 0.90, 7: 0.95, 8: 1.0, 9: 0.95,
              10: 1.05, 11: 1.10, 12: 1.30}[d.month]
    bf = black_friday(d.year)
    semana_black_friday = bf - dt.timedelta(4) <= d <= bf + dt.timedelta(3)
    if d == bf:
        fator *= 5
    elif semana_black_friday:
        fator *= 1.8 * (1.3 if d == bf + dt.timedelta(3) else 1)     # semana da Black Friday e Cyber Monday
    if d.month == 12 and d.day <= 20 and not semana_black_friday:
        fator *= 1.25                                                 # compras de Natal
    if (d.month, d.day) in {(12, 24), (12, 25), (12, 31), (1, 1)}:
        fator *= 0.45
    if (d.month, d.day) == (10, 29):
        fator *= 2.2                                                  # Dia Nacional do Livro
    if (d.month, d.day) == (4, 23):
        fator *= 1.6                                                  # Dia Mundial do Livro
    return fator


def pedidos_esperados(d):
    return PEDIDOS_POR_DIA * (1 + CRESCIMENTO_ANUAL) ** ((d - INICIO).days / 365) * fator_do_dia(d)


def campanha_do_dia(d):
    """Campanha sazonal, cupom da campanha e desconto de vitrine do dia."""
    bf = black_friday(d.year)
    if bf - dt.timedelta(4) <= d <= bf + dt.timedelta(3):
        return f"black_friday_{d.year}", "BLACKLIVROS", 0.30 if d in (bf, bf + dt.timedelta(3)) else 0.15
    if (2, 1) <= (d.month, d.day) <= (3, 10):
        return "volta_as_aulas", "VOLTAASAULAS", 0.0
    if d.month == 12 and d.day <= 24:
        return f"natal_{d.year}", "NATAL15", 0.0
    if d.month == 10 and d.day >= 20:
        return "mes_do_livro", "LIVRO20", 0.20 if d.day == 29 else 0.0
    return None, None, 0.0


def sazonalidade_das_categorias(d):
    """Algumas categorias vendem mais em certas épocas."""
    extra = {}
    if (1, 15) <= (d.month, d.day) <= (3, 15):
        extra["Didático"] = 4.0
    if (d.month == 10 and d.day <= 12) or d.month == 12:
        extra["Infantil"] = 2.0                                       # Dia das Crianças e Natal
    if d.month == 12:
        extra["Culinária"], extra["Biografia"] = 1.6, 1.4
    return extra


def gerar_vendas(produtos, clientes):
    sku = produtos["SKU"].to_numpy()
    titulo = produtos["Título"].to_numpy()
    formato = produtos["Formato"].to_numpy()
    categoria = produtos["Categoria"].to_numpy()
    popularidade = produtos["_popularidade"].to_numpy()
    cadastro = np.array([d.toordinal() for d in produtos["Data de Cadastro"]])
    lancamento = produtos["Ano de Publicação"].to_numpy() >= INICIO.year
    preco_2025 = produtos["Preço de Capa"].to_numpy()

    cli_id = clientes["ID Cliente"].to_numpy()
    cli_uf = clientes["UF"].to_numpy()
    cli_cidade = clientes["Cidade"].to_numpy()
    cli_cep = clientes["CEP"].to_numpy()
    chance_de_voltar = clientes["_chance_de_voltar"].to_numpy()

    linhas = []
    contador = {}
    ja_compraram = 0                     # os clientes 0 .. ja_compraram-1 já fizeram pedido
    agenda = {}                          # dia (ordinal) -> clientes que voltam a comprar nesse dia
    for d in DIAS:
        ano = d.year
        campanha, cupom_campanha, desconto_vitrine = campanha_do_dia(d)
        k = rng.poisson(pedidos_esperados(d))

        # clientes do dia: primeiro os que estavam agendados para voltar; o resto são clientes novos.
        # Se a agenda passar do total do dia, o excedente fica para o dia seguinte.
        voltam = agenda.pop(d.toordinal(), [])
        if len(voltam) > k:
            agenda.setdefault(d.toordinal() + 1, []).extend(voltam[k:])
            voltam = voltam[:k]
        novos = min(k - len(voltam), N_CLIENTES - ja_compraram)
        cliente = np.array(voltam + list(range(ja_compraram, ja_compraram + novos)), dtype=int)
        ja_compraram += novos
        k = len(cliente)
        rng.shuffle(cliente)
        # cada cliente do dia decide se vai voltar e quando (pela chance dele)
        volta = rng.random(k) < chance_de_voltar[cliente]
        espera = rng.exponential(DIAS_ATE_VOLTAR, k).astype(int) + 7
        for c, dias in zip(cliente[volta], espera[volta]):
            agenda.setdefault(d.toordinal() + int(dias), []).append(int(c))

        # o que vale para o pedido inteiro, sorteado para os k pedidos do dia de uma vez
        app = rng.random(k) < PARTE_APP[ano]
        dispositivo = np.where(app, "app", escolher(["desktop", "mobile", "tablet"], DISPOSITIVO_SITE[ano], k))
        origens = [o for o, (_, desde) in ORIGENS.items() if desde <= ano]
        origem = escolher(len(origens), [ORIGENS[o][0] for o in origens], k)
        pagamento = escolher(PAGAMENTOS, PESO_PAGAMENTO[ano], k)
        n_itens = np.minimum(1 + rng.poisson(0.45, k), 6)

        # quais livros saem hoje: popularidade x já cadastrado x época x lançamento recente
        dias_de_casa = d.toordinal() - cadastro
        peso = popularidade * (dias_de_casa >= 0)
        peso = peso * np.where(lancamento & (dias_de_casa < 90), 2.5, 1.0)
        for cat, mult in sazonalidade_das_categorias(d).items():
            peso = peso * np.where(categoria == cat, mult, 1.0)
        acumulado = np.cumsum(peso)
        sorteados = np.searchsorted(acumulado, rng.random(n_itens.sum()) * acumulado[-1])
        preco_do_ano = preco_redondo(preco_2025 / (1 + REAJUSTE_ANUAL) ** (2025 - ano))

        inicio_itens = 0
        for p in range(k):
            contador[ano] = contador.get(ano, 0) + 1                 # número do pedido recomeça a cada ano
            pedido = f"P{ano}-{contador[ano]:06d}"
            itens = {}
            for i in sorted(sorteados[inicio_itens:inicio_itens + n_itens[p]]):
                qtd = int(escolher([1, 2, 3], [75, 15, 10] if categoria[i] == "Didático" else [90, 8, 2]))
                itens[i] = itens.get(i, 0) + qtd                       # mesmo livro duas vezes: soma
            inicio_itens += n_itens[p]

            o, m = origens[origem[p]]
            if cupom_campanha and rng.random() < 0.30:
                cupom = cupom_campanha
            elif rng.random() < 0.10:
                cupom = str(rng.choice(["LEITURA10", "BEMVINDO", "FRETEGRATIS"]))
            else:
                cupom = None
            if m in ("cpc", "email"):
                nome_campanha = campanha or ("always_on" if m == "cpc" else "newsletter_semanal")
            elif m == "social":
                nome_campanha = "influenciadores" if o in ("instagram", "tiktok") else "conteudo"
            elif m == "affiliate":
                nome_campanha = "parceiros"
            else:
                nome_campanha = None

            valores = []
            for i, qtd in itens.items():
                vitrine = desconto_vitrine if rng.random() < 0.40 or (d.month, d.day) == (10, 29) else 0.0
                pct = max(CUPONS.get(cupom, 0.0), vitrine)
                bruto = qtd * preco_do_ano[i]
                valores.append((i, qtd, preco_do_ano[i], round(bruto * pct, 2), round(bruto - bruto * pct, 2)))
            subtotal = sum(v[4] for v in valores)

            so_ebook = all(formato[i] == "E-book" for i in itens)
            entrega = "Digital" if so_ebook else ("Expressa" if rng.random() < 0.18 else "Normal")
            uf = cli_uf[cliente[p]]
            if entrega == "Digital" or subtotal >= 149.90 or cupom == "FRETEGRATIS":
                frete = 0.0
            else:
                frete = (14.90 if uf in FRETE_BARATO else 24.90) + (17.00 if entrega == "Expressa" else 0)
            total = round(subtotal + frete, 2)
            parcelas = None
            if pagamento[p] == "Cartão de crédito":
                parcelas = 1 if total < 80 else int(escolher([1, 2, 3, 4, 5, 6], [40, 15, 15, 10, 10, 10]))

            sorteio = rng.random()
            if pagamento[p] == "Boleto" and sorteio < 0.22:
                status = "Cancelado"                                   # boleto não pago
            elif sorteio < 0.045:
                status = "Cancelado"
            elif sorteio < 0.06:
                status = "Devolvido"
            elif (FIM - d).days < 7:
                status = "Aguardando pagamento" if pagamento[p] == "Boleto" else \
                    str(escolher(["Faturado", "Em transporte"], [5, 4]))
            else:
                status = "Entregue"
            data_entrega = None
            if status in ("Entregue", "Devolvido"):
                prazo = 0 if entrega == "Digital" else int(rng.integers(1, 5) if entrega == "Expressa"
                                                           else rng.integers(3, 13))
                data_entrega = d + dt.timedelta(prazo + (0 if uf in FRETE_BARATO or prazo == 0 else 2))
            avaliacao = None
            if status == "Entregue" and rng.random() < 0.20:
                avaliacao = int(escolher([1, 2, 3, 4, 5], [2, 3, 8, 25, 62]))

            for n, (i, qtd, preco, desconto, valor) in enumerate(valores, 1):
                linhas.append({
                    "Pedido": pedido, "Item": n, "Data do Pedido": d, "Status": status,
                    "ID Cliente": int(cli_id[cliente[p]]), "UF": uf, "Cidade": cli_cidade[cliente[p]],
                    "CEP": int(cli_cep[cliente[p]]), "Canal": "App" if app[p] else "Site",
                    "Origem": o, "Mídia": m, "Campanha": nome_campanha, "Cupom": cupom,
                    "Forma de Pagamento": str(pagamento[p]), "Parcelas": parcelas,
                    "SKU": int(sku[i]), "Produto": titulo[i], "Formato": formato[i], "Quantidade": qtd,
                    "Preço Unitário": float(preco), "Desconto": desconto, "Valor Item": valor,
                    "Tipo de Entrega": entrega, "Frete Pedido": frete, "Valor Total Pedido": total,
                    "Data de Entrega": data_entrega, "Avaliação": avaliacao,
                    "Obs Interna": str(rng.choice(OBSERVACOES)) if rng.random() < 0.03 else None,
                    "_dispositivo": str(dispositivo[p]),
                })
    return pd.DataFrame(linhas)


# ---------------------------------------------------------------------------------------
# Sessões, marketing e metas: calculados a partir das vendas
# ---------------------------------------------------------------------------------------

def gerar_sessoes(pedidos):
    grade = pd.MultiIndex.from_product([DIAS, list(CONVERSAO_DISPOSITIVO)], names=["dia", "disp"])
    por_dia = (pedidos.groupby(["Data do Pedido", "_dispositivo"])["Valor Total Pedido"]
               .agg(["size", "sum"]).reindex(grade, fill_value=0).reset_index())
    conversao = por_dia["disp"].map(CONVERSAO_DISPOSITIVO)
    sessoes = np.round(np.maximum(por_dia["size"], 1) / conversao * rng.lognormal(0, 0.07, len(por_dia)))
    usuarios = np.round(sessoes * rng.uniform(0.72, 0.82, len(por_dia)))
    rastreados = rng.binomial(por_dia["size"], 0.93)            # o site não registra todos os pedidos
    tabela = pd.DataFrame({
        "Data": [int(d.strftime("%Y%m%d")) for d in por_dia["dia"]],
        "Dispositivo": por_dia["disp"],
        "Sessões": sessoes.astype(int),
        "Usuários": usuarios.astype(int),
        "Novos Usuários": np.round(usuarios * rng.uniform(0.30, 0.42, len(por_dia))).astype(int),
        "Pedidos": rastreados,
        "Receita": np.round(por_dia["sum"] * rastreados / np.maximum(por_dia["size"], 1), 2),
    })
    # sujeira: "APP" em maiúsculo no inverno de 2024; "Mobile" com maiúscula às vezes
    inverno = (tabela["Data"] >= 20240601) & (tabela["Data"] <= 20240831) & (tabela["Dispositivo"] == "app")
    tabela.loc[inverno, "Dispositivo"] = "APP"
    tabela.loc[(tabela["Dispositivo"] == "mobile") & (rng.random(len(tabela)) < 0.01), "Dispositivo"] = "Mobile"
    # sujeira: 12 dias com o desktop repetido (valores diferentes), logo abaixo da linha certa
    linhas = []
    repetidos = set(rng.choice(len(DIAS), 12, replace=False))
    for n, linha in enumerate(tabela.to_dict("records")):
        linhas.append(linha)
        if linha["Dispositivo"] == "desktop" and n // 4 in repetidos:
            copia = dict(linha)
            for coluna in ("Sessões", "Usuários", "Novos Usuários"):
                copia[coluna] = int(copia[coluna] * rng.uniform(0.3, 1.5))
            linhas.append(copia)
    tabela = pd.DataFrame(linhas)
    total = {"Data": "Total", "Dispositivo": None}
    total.update(tabela.drop(columns=["Data", "Dispositivo"]).sum().round(2).to_dict())
    return pd.concat([tabela, pd.DataFrame([total])], ignore_index=True)


def gerar_marketing(pedidos):
    grupo = pedidos.groupby(["Data do Pedido", "Origem", "Mídia"])["Valor Total Pedido"].agg(["size", "sum"])
    grupo = grupo.reset_index()
    rastreados = rng.binomial(grupo["size"], 0.92)
    conversao = grupo["Mídia"].map(CONVERSAO_ORIGEM)
    base = pd.DataFrame({
        "Data": grupo["Data do Pedido"],
        "Origem / Mídia": grupo["Origem"] + " / " + grupo["Mídia"],
        "Sessões": np.round(grupo["size"] / conversao * rng.lognormal(0, 0.10, len(grupo))).astype(int),
        "Transações": rastreados,
        # a ferramenta de análise devolve a receita com muitas casas decimais
        "Receita": grupo["sum"] * rastreados / grupo["size"] * rng.uniform(0.995, 1.005, len(grupo)),
    })
    pinterest = pd.DataFrame({"Data": DIAS, "Origem / Mídia": "pinterest / social",
                              "Sessões": rng.poisson(80, len(DIAS)), "Transações": 0, "Receita": 0.0})
    base = pd.concat([base, pinterest]).sort_values(["Data", "Origem / Mídia"], ignore_index=True)
    base.loc[rng.choice(len(base), 6, replace=False), "Origem / Mídia"] = None    # sujeira: sem origem

    depara = pd.DataFrame(list(CANAL_MKT.items()), columns=["Origem / Mídia", "Canal"])
    depara = pd.concat([depara, depara.iloc[[0]]], ignore_index=True)             # sujeira: linha repetida
    return base, depara


def gerar_metas(pedidos):
    ticket = pedidos.groupby([pd.to_datetime(pedidos["Data do Pedido"]).dt.to_period("M")])[
        "Valor Total Pedido"].mean()
    linhas = []
    for d in DIAS:
        if d == dt.date(2024, 2, 29):
            continue                                                 # sujeira: alguém esqueceu o dia 29
        meta_pedidos = round(pedidos_esperados(d) * 1.05)
        linhas.append({"Data": d,
                       "Meta Receita": round(meta_pedidos * ticket[pd.Period(d, "M")], -1),
                       "Meta Pedidos": meta_pedidos,
                       "Meta Sessões": round(meta_pedidos / 0.016, -2)})
    return pd.DataFrame(linhas)


# ---------------------------------------------------------------------------------------
# Sujeira das vendas e gravação dos Excel
# ---------------------------------------------------------------------------------------

def variar_grafia(serie, fracao):
    """Parte dos textos em MAIÚSCULO, minúsculo ou com espaço no fim."""
    serie = serie.copy()
    sorteio = rng.random(len(serie))
    tipo = np.select([sorteio < fracao / 3, sorteio < 2 * fracao / 3, sorteio < fracao], [1, 2, 3], 0)
    serie[tipo == 1] = serie[tipo == 1].str.upper()
    serie[tipo == 2] = serie[tipo == 2].str.lower()
    serie[tipo == 3] = serie[tipo == 3] + " "
    return serie


def corromper_acentos(texto):
    """Simula o erro de um arquivo UTF-8 aberto como Windows-1252: "ção" vira "Ã§Ã£o"."""
    return "".join(bytes([b]).decode("cp1252", errors="ignore") or chr(b) for b in texto.encode("utf-8"))


COLUNAS_VENDAS = ["Pedido", "Item", "Data do Pedido", "Status", "ID Cliente", "UF", "Cidade", "CEP",
                  "Canal", "Origem", "Mídia", "Campanha", "Cupom", "Forma de Pagamento", "Parcelas", "SKU",
                  "Produto", "Formato", "Quantidade", "Preço Unitário", "Desconto", "Valor Item",
                  "Tipo de Entrega", "Frete Pedido", "Valor Total Pedido", "Data de Entrega"]


def vendas_do_ano(vendas, ano):
    tabela = vendas[pd.to_datetime(vendas["Data do Pedido"]).dt.year == ano].reset_index(drop=True)
    tabela["Status"] = variar_grafia(tabela["Status"], 0.04)
    extenso = rng.random(len(tabela)) < 0.02
    tabela.loc[extenso, "UF"] = tabela.loc[extenso, "UF"].map(NOME_DA_UF)

    if ano == 2023:
        colunas = [c for c in COLUNAS_VENDAS if c not in ("Canal", "Tipo de Entrega")] + ["Obs Interna"]
        tabela = tabela[colunas].astype({"Preço Unitário": object})
        for coluna in ("Data do Pedido", "Data de Entrega"):            # datas exportadas como texto
            tabela[coluna] = [d.strftime("%d/%m/%Y") if pd.notna(d) else None for d in tabela[coluna]]
        texto = rng.random(len(tabela)) < 0.01
        tabela.loc[texto, "Preço Unitário"] = [f"R$ {v:.2f}".replace(".", ",")
                                              for v in tabela.loc[texto, "Preço Unitário"]]
    elif ano == 2024:
        tabela = tabela[COLUNAS_VENDAS].copy()
        corrompido = rng.random(len(tabela)) < 0.04
        tabela.loc[corrompido, "Produto"] = tabela.loc[corrompido, "Produto"].map(corromper_acentos)
        dia = tabela.index[tabela["Data do Pedido"] == dt.date(2024, 3, 11)]   # dia colado duas vezes
        tabela = pd.concat([tabela.loc[:dia[-1]], tabela.loc[dia], tabela.loc[dia[-1] + 1:]],
                           ignore_index=True)
    else:
        tabela = tabela[COLUNAS_VENDAS + ["Avaliação"]].rename(columns={"Forma de Pagamento": "Pagamento"})
    return tabela


def salvar_excel(caminho, abas):
    """abas = {nome da aba: (tabela, linhas de título acima do cabeçalho)}"""
    caminho.parent.mkdir(parents=True, exist_ok=True)
    livro = Workbook(write_only=True)
    for nome, (tabela, titulo) in abas.items():
        aba = livro.create_sheet(nome)
        for texto in titulo:
            aba.append([texto])
        aba.append(list(tabela.columns))
        for linha in tabela.astype(object).where(tabela.notna(), None).itertuples(index=False):
            valores = []
            for valor in linha:
                if isinstance(valor, dt.date):
                    valor = WriteOnlyCell(aba, value=valor)
                    valor.number_format = "dd/mm/yyyy"
                valores.append(valor)
            aba.append(valores)
    livro.save(caminho)


def main():
    inicio = time.time()
    produtos = gerar_catalogo()
    clientes = gerar_clientes()
    print(f"catálogo: {len(produtos):,} SKUs de {N_OBRAS:,} livros")
    vendas = gerar_vendas(produtos, clientes)
    pedidos = vendas.drop_duplicates("Pedido")
    print(f"vendas: {len(vendas):,} itens em {len(pedidos):,} pedidos de {pedidos['ID Cliente'].nunique():,} "
          f"clientes ({time.time() - inicio:.0f} s)")

    for ano in (2023, 2024, 2025):
        tabela = vendas_do_ano(vendas, ano)
        salvar_excel(PASTA / "vendas" / f"vendas_{ano}.xlsx", {"Pedidos": (tabela, [])})
        print(f"vendas_{ano}.xlsx: {len(tabela):,} linhas ({time.time() - inicio:.0f} s)")

    catalogo = produtos.drop(columns="_popularidade")
    catalogo["Categoria"] = variar_grafia(catalogo["Categoria"], 0.06)
    atualizados = catalogo.sample(12, random_state=SEMENTE).assign(**{"Preço de Capa": lambda t: t["Preço de Capa"] + 5})
    catalogo = pd.concat([catalogo, atualizados], ignore_index=True)        # SKU repetido, preço novo embaixo
    titulo = ["Catálogo de produtos – Livraria Capítulo Um (dados fictícios)", "Exportado em 31/12/2025"]
    salvar_excel(PASTA / "produtos.xlsx", {"Catalogo": (catalogo, titulo)})
    print(f"produtos.xlsx: {len(catalogo):,} linhas")

    sessoes = gerar_sessoes(pedidos)
    salvar_excel(PASTA / "sessoes.xlsx", {"Sessoes": (sessoes, [])})
    print(f"sessoes.xlsx: {len(sessoes):,} linhas")

    base, depara = gerar_marketing(pedidos)
    salvar_excel(PASTA / "marketing.xlsx", {"Base": (base, []), "DePara": (depara, [])})
    print(f"marketing.xlsx: {len(base):,} linhas na Base, {len(depara)} no DePara")

    metas = gerar_metas(pedidos)
    salvar_excel(PASTA / "metas.xlsx", {"Metas": (metas, [])})
    print(f"metas.xlsx: {len(metas):,} linhas")
    print(f"\nPronto em {time.time() - inicio:.0f} s: {PASTA}")


if __name__ == "__main__":
    main()
