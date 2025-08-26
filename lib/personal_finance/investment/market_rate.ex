defmodule PersonalFinance.Investment.MarketRate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "market_rates" do
    field :type, Ecto.Enum, values: [:cdi, :ipca, :selic]
    field :value, :decimal
    field :date, :date

    timestamps()
  end

  def changeset(market_rate, attrs) do
    market_rate
    |> cast(attrs, [:type, :value, :date])
    |> validate_required([:type, :value, :date])
  end
end
