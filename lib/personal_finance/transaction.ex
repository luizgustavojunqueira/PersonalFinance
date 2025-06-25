defmodule PersonalFinance.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :value, :float
    field :total_value, :float
    field :amount, :float
    field :description, :string
    field :date, :date
    field :category, :string
    field :type, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:value, :total_value, :amount, :description, :date, :category, :type])
    |> validate_required([:value, :total_value, :amount, :description, :date, :category, :type])
  end
end
