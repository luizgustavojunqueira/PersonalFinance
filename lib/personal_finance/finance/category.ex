defmodule PersonalFinance.Finance.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field :name, :string
    field :description, :string
    field :percentage, :float, default: 0.0
    belongs_to :user, PersonalFinance.Accounts.User, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :description, :user_id, :percentage])
    |> validate_required([:name, :user_id, :percentage])
    |> unique_constraint(:name, name: :categories_name_index)
    |> foreign_key_constraint(:user_id, name: :categories_user_id_fkey)
    |> validate_number(:percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
