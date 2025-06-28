defmodule PersonalFinance.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :value, :float
    field :total_value, :float
    field :amount, :float
    field :description, :string
    field :date, :date
    belongs_to :category, PersonalFinance.Category
    belongs_to :investment_type, PersonalFinance.InvestmentType
    belongs_to :profile, PersonalFinance.Profile
    belongs_to :user, PersonalFinance.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :value,
      :total_value,
      :amount,
      :description,
      :date,
      :category_id,
      :investment_type_id,
      :profile_id,
      :user_id
    ])
    |> validate_required([
      :value,
      :total_value,
      :amount,
      :description,
      :date,
      :category_id,
      :profile_id,
      :user_id
    ])
  end
end
