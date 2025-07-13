defmodule PersonalFinance.Finance.Ledger do
  use Ecto.Schema
  import Ecto.Changeset

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
    |> validate_required([:name], message: "O nome é obrigatório.")
    |> validate_length(:name,
      min: 1,
      max: 100,
      message: "O nome deve ter entre 1 e 100 caracteres."
    )
    |> validate_length(:description,
      max: 255,
      message: "A descrição deve ter no máximo 255 caracteres."
    )
    |> put_change(:owner_id, owner_id)
    |> unique_constraint(:name,
      name: :ledgers_name_owner_id_index,
      message: "Já existe um orçamento com esse nome para este usuário."
    )
  end
end
