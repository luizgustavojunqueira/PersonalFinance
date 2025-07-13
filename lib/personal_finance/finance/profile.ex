defmodule PersonalFinance.Finance.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profiles" do
    field :name, :string
    field :description, :string, default: nil
    field :is_default, :boolean, default: false
    belongs_to :ledger, PersonalFinance.Finance.Ledger

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs, ledger_id) do
    profile
    |> cast(attrs, [:name, :description, :is_default])
    |> validate_required([:name], message: "O nome é obrigatório.")
    |> validate_required([:description], message: "A descrição é obrigatória.")
    |> validate_inclusion(:is_default, [true, false],
      message: "O valor deve ser verdadeiro ou falso."
    )
    |> validate_length(:name,
      min: 1,
      max: 100,
      message: "O nome deve ter entre 1 e 100 caracteres."
    )
    |> validate_length(:description,
      max: 255,
      message: "A descrição deve ter no máximo 255 caracteres."
    )
    |> unique_constraint(:name,
      name: :profiles_name_ledger_id_index,
      message: "Já existe um perfil com este nome para este orçamento."
    )
    |> unique_constraint(:is_default,
      name: :unique_default_profile_per_ledger,
      where: "is_default = true",
      message: "Já existe um perfil padrão para este orçamento."
    )
    |> put_change(:ledger_id, ledger_id)
  end
end
