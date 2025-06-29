defmodule PersonalFinance.Finance.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profiles" do
    field :name, :string
    field :description, :string, default: nil
    belongs_to :budget, PersonalFinance.Finance.Budget

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:name, :description, :budget_id])
    |> validate_required([:name, :budget_id, :description])
  end
end
