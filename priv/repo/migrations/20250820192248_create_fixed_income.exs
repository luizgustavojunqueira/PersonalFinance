defmodule PersonalFinance.Repo.Migrations.CreateFixedIncome do
  use Ecto.Migration

  def change do
    create table(:fixed_income) do
      add :name, :string, null: false
      add :institution, :string, null: false
      add :type, :string, null: false
      add :start_date, :date, null: false
      add :end_date, :date, null: true
      add :remuneration_rate, :decimal, precision: 10, scale: 6, null: false
      add :remuneration_basis, :string, null: false
      add :yield_frequency, :string, null: false
      add :is_tax_exempt, :boolean, default: false, null: false
      add :initial_investment, :float, null: false
      add :current_balance, :float, null: false
      add :last_yield_date, :date, null: true

      add :profile_id, references(:profiles, on_delete: :nothing), null: false
      add :ledger_id, references(:ledgers, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create table(:fixed_income_transactions) do
      add :type, :string, null: false
      add :value, :decimal, precision: 15, scale: 2, null: false
      add :date, :date, null: false
      add :description, :string, null: true
      add :yield_rate, :decimal, precision: 10, scale: 6, null: true

      add :is_automatic, :boolean, default: false, null: false
      add :reference_period, :string, null: true

      add :fixed_income_id, references(:fixed_income, on_delete: :delete_all), null: false
      add :profile_id, references(:profiles, on_delete: :nothing), null: false
      add :ledger_id, references(:ledgers, on_delete: :delete_all), null: false
      add :transaction_id, references(:transactions, on_delete: :nothing), null: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:fixed_income, [:name, :profile_id],
             name: :fixed_income_name_profile_id_index
           )
  end
end
