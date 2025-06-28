defmodule PersonalFinance.Finance.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profiles" do
    field :name, :string
    field :description, :string, default: nil
    belongs_to :user, PersonalFinance.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:name, :description, :user_id])
    |> validate_required([:name, :user_id, :description])
    |> unique_constraint(:name, name: :profiles_name_user_id_index)
  end
end
