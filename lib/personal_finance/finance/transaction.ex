defmodule PersonalFinance.Finance.Transaction do
  use Ecto.Schema
  import Ecto.Changeset
  alias PersonalFinance.Finance.{Category, InvestmentType, Profile}

  schema "transactions" do
    field :value, :float
    field :total_value, :float
    field :amount, :float
    field :description, :string
    field :date, :date
    belongs_to :category, Category
    belongs_to :investment_type, InvestmentType
    belongs_to :profile, Profile
    belongs_to :budget, PersonalFinance.Finance.Budget

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs, budget_id) do
    transaction
    |> cast(attrs, [
      :value,
      :total_value,
      :amount,
      :description,
      :date,
      :investment_type_id,
      :category_id,
      :profile_id
    ])
    |> validate_required([:value], message: "O valor da transação é obrigatório")
    |> validate_required([:amount], message: "A quantidade é obrigatória")
    |> validate_required([:description], message: "A descrição é obrigatória")
    |> validate_required([:date], message: "A data é obrigatória")
    |> validate_required([:profile_id], message: "Selecione um perfil")
    |> put_change(:budget_id, budget_id)
  end
end
