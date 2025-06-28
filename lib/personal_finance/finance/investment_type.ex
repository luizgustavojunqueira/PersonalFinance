defmodule PersonalFinance.Finance.InvestmentType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "investment_types" do
    field :name, :string
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(investment_type, attrs) do
    investment_type
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> unique_constraint(:name, name: :investment_types_name_index)
  end
end
