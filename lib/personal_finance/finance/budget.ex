defmodule PersonalFinance.Finance.Budget do
  use Ecto.Schema
  import Ecto.Changeset

  schema "budgets" do
    field :name, :string
    field :description, :string, default: nil
    belongs_to :owner, PersonalFinance.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(budget, attrs, owner_id) do
    budget
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> put_change(:owner_id, owner_id)
    |> unique_constraint(:name,
      name: :budgets_name_owner_id_index,
      message: "Já existe um orçamento com esse nome para este usuário."
    )
  end
end
