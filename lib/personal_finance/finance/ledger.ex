defmodule PersonalFinance.Finance.Ledger do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PersonalFinanceWeb.Gettext

  schema "ledgers" do
    field :name, :string
    field :description, :string, default: nil
    belongs_to :owner, PersonalFinance.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ledger, attrs, owner_id) do
    ledger
    |> cast(attrs, [:name, :description])
    |> validate_required([:name], message: gettext("Name is required."))
    |> validate_length(:name,
      min: 1,
      max: 100,
      message: gettext("Name must be between 1 and 100 characters.")
    )
    |> validate_length(:description,
      max: 255,
      message: gettext("Description must be at most 255 characters.")
    )
    |> put_change(:owner_id, owner_id)
    |> unique_constraint(:name,
      name: :ledgers_name_owner_id_index,
      message: gettext("A ledger with this name already exists for this owner.")
    )
  end
end
