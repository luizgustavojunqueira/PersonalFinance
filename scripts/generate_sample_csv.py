import csv
from datetime import date, timedelta
from pathlib import Path

OUTPUT_PATH = Path("priv/static/sample_transactions.csv")

CATEGORIES = [
    "Mercado",
    "Utilidades",
    "Salario",
    "Lazer",
    "Viagem",
]

INVESTMENT_TYPES = [
    "",
    "Renda Fixa",
    "Ações",
    "",
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

BASE_DATE = date(2024, 1, 1)


def build_rows(count: int = 100):
    rows = []
    for i in range(count):
        current_date = BASE_DATE + timedelta(days=i)
        value = round(25.75 + (i % 9) * 4.1, 2)
        value_str = ("R$ %.2f" % value).replace(".", ",")
        amount = 1 + (i % 3) * 0.5
        amount_str = ("%.2f" % amount).replace(".", ",")
        time_str = f"{(8 + i) % 24:02d}:{(17 * i) % 60:02d}"
        category = CATEGORIES[i % len(CATEGORIES)]
        investment_type = INVESTMENT_TYPES[i % len(INVESTMENT_TYPES)]
        type_value = "income" if i % 7 == 0 else "expense"

        rows.append(
            {
                "date": current_date.isoformat(),
                "time": time_str,
                "description": f"Imported transaction {i + 1}",
                "value": value_str,
                "amount": amount_str,
                "category": category,
                "profile": "",
                "investment_type": investment_type,
                "type": type_value,
            }
        )

    return rows


def main():
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    rows = build_rows(100)

    with OUTPUT_PATH.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Generated {len(rows)} rows at {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
