import csv
import random
from datetime import date, timedelta
from pathlib import Path

OUTPUT_PATH = Path("priv/static/sample_transactions.csv")

# Categorias conforme solicitado
EXPENSE_CATEGORIES = [
    "Prazeres",
    "Despesas",
    "Conhecimento",
    "Metas",
]

INCOME_CATEGORIES = [
    "Sem categoria",
]

INVESTMENT_CATEGORIES = [
    "Investimento",
]

INVESTMENT_TYPES = [
    "",
    "Renda Fixa",
    "Ações",
    "Tesouro Direto",
]

FIELDNAMES = [
    "date",
    "time",
    "description",
    "value",
    "amount",
    "category",
    "profile",
    "investment_type",
    "type",
]

BASE_DATE = date(2025, 1, 1)


def build_rows(count: int = 100):
    rows = []
    
    # Gerar transações ao longo do ano (365 dias)
    days_in_year = 365
    
    # Receitas mensais (salário e rendimentos)
    monthly_income = 4000.00  # Receita base mensal
    
    # Gerar transações dia a dia
    for day in range(days_in_year):
        current_date = BASE_DATE + timedelta(days=day)
        day_of_month = current_date.day
        
        # Salário no dia 5 de cada mês
        if day_of_month == 5:
            salary = monthly_income + random.uniform(-200, 500)
            time_str = "09:00"
            rows.append({
                "date": current_date.isoformat(),
                "time": time_str,
                "description": "Salário mensal",
                "value": format_value(salary),
                "amount": "1,00",
                "category": random.choice(INCOME_CATEGORIES),
                "profile": "",
                "investment_type": "",
                "type": "income",
            })
        
        # Rendimentos de investimentos no dia 1 de cada mês
        if day_of_month == 1:
            investment_yield = random.uniform(50, 200)
            time_str = "00:01"
            rows.append({
                "date": current_date.isoformat(),
                "time": time_str,
                "description": "Rendimento de investimentos",
                "value": format_value(investment_yield),
                "amount": "1,00",
                "category": random.choice(INCOME_CATEGORIES),
                "profile": "",
                "investment_type": random.choice(INVESTMENT_TYPES[1:]),
                "type": "income",
            })
        
        # Despesas variadas (1-2 por dia em média)
        num_expenses = random.randint(0, 3) if day_of_month % 3 == 0 else random.randint(0, 2)
        for _ in range(num_expenses):
            # Despesas menores para manter saldo positivo
            expense_value = random.uniform(15, 80)
            hour = random.randint(8, 22)
            minute = random.randint(0, 59)
            time_str = f"{hour:02d}:{minute:02d}"
            
            category = random.choice(EXPENSE_CATEGORIES)
            
            # Descrições por categoria
            descriptions = {
                "Prazeres": ["Cinema", "Restaurante", "Streaming", "Games", "Livros"],
                "Despesas": ["Mercado", "Farmácia", "Uber", "Combustível", "Conta de luz"],
                "Conhecimento": ["Curso online", "Livro técnico", "Workshop", "Certificação"],
                "Metas": ["Reserva de emergência", "Aposentadoria", "Viagem dos sonhos"],
            }
            
            description = random.choice(descriptions[category])
            
            rows.append({
                "date": current_date.isoformat(),
                "time": time_str,
                "description": description,
                "value": format_value(expense_value),
                "amount": "1,00",
                "category": category,
                "profile": "",
                "investment_type": "",
                "type": "expense",
            })
        
        # Investimentos (1 vez por mês)
        if day_of_month == 15:
            investment_amount = random.uniform(300, 600)
            time_str = "14:30"
            rows.append({
                "date": current_date.isoformat(),
                "time": time_str,
                "description": "Aplicação em investimento",
                "value": format_value(investment_amount),
                "amount": "1,00",
                "category": random.choice(INVESTMENT_CATEGORIES),
                "profile": "",
                "investment_type": random.choice(INVESTMENT_TYPES[1:]),
                "type": "expense",
            })
    
    return rows


def format_value(value: float) -> str:
    """Formata valor para o padrão brasileiro (R$ 1.234,56)"""
    return ("R$ %.2f" % value).replace(".", ",")


def main():
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    rows = build_rows()

    with OUTPUT_PATH.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Generated {len(rows)} transactions for the entire year at {OUTPUT_PATH}")
    
    # Calcular totais para verificação
    total_income = sum(float(row['value'].replace('R$ ', '').replace(',', '.')) 
                      for row in rows if row['type'] == 'income')
    total_expense = sum(float(row['value'].replace('R$ ', '').replace(',', '.')) 
                       for row in rows if row['type'] == 'expense')
    
    print(f"Total income: R$ {total_income:,.2f}")
    print(f"Total expenses: R$ {total_expense:,.2f}")
    print(f"Net result: R$ {total_income - total_expense:,.2f}")
    print(f"Income > Expenses: {total_income > total_expense}")


if __name__ == "__main__":
    main()
