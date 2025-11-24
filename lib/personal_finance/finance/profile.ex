defmodule PersonalFinance.Finance.Profile do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PersonalFinanceWeb.Gettext

  schema "profiles" do
    field :name, :string
    field :description, :string, default: nil
    field :is_default, :boolean, default: false
    field :color, :string, default: "#000000"
    belongs_to :ledger, PersonalFinance.Finance.Ledger

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs, ledger_id) do
    profile
    |> cast(attrs, [:name, :description, :is_default, :color])
    |> validate_required([:name], message: gettext("Name is required."))
    |> validate_required([:description], message: gettext("Description is required."))
    |> validate_inclusion(:is_default, [true, false],
      message: gettext("Value must be true or false.")
    )
    |> validate_length(:name,
      min: 1,
      max: 100,
      message: gettext("Name must be between 1 and 100 characters.")
    )
    |> validate_length(:description,
      max: 255,
      message: gettext("Description must be at most 255 characters.")
    )
    |> unique_constraint(:name,
      name: :profiles_name_ledger_id_index,
      message: gettext("A profile with this name already exists for this ledger.")
    )
    |> unique_constraint(:is_default,
      name: :unique_default_profile_per_ledger,
      where: "is_default = true",
      message: gettext("A default profile already exists for this ledger.")
    )
    |> put_change(:ledger_id, ledger_id)
  end
end
