defmodule PersonalFinance.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field :name, :string
    field :description, :string
    belongs_to :user, PersonalFinance.Accounts.User, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :description, :user_id])
    |> validate_required([:name, :user_id])
    |> unique_constraint(:name, name: :categories_name_index)
  end
end
