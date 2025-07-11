defmodule PersonalFinance.Finance.Category do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "categories" do
    field :name, :string
    field :description, :string
    field :percentage, :float, default: 0.0
    field :is_default, :boolean, default: false
    field :is_fixed, :boolean, default: false
    belongs_to :budget, PersonalFinance.Finance.Budget

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs, budget_id) do
    category
    |> cast(attrs, [:name, :description, :percentage, :is_default, :is_fixed])
    |> validate_required([:name], message: "O nome é obrigatório.")
    |> validate_required([:description], message: "A descrição é obrigatória.")
    |> validate_required([:percentage], message: "A porcentagem é obrigatória.")
    |> validate_required([:is_default])
    |> validate_length(:name,
      min: 1,
      max: 100,
      message: "O nome deve ter entre 1 e 100 caracteres."
    )
    |> validate_length(:description,
      max: 500,
      message: "A descrição deve ter no máximo 500 caracteres."
    )
    |> validate_inclusion(:is_default, [true, false])
    |> unique_constraint(:is_default,
      name: :unique_default_category_per_budget,
      where: "is_default = true"
    )
    |> unique_constraint(:name,
      name: :categories_name_budget_id_index,
      message: "Já existe uma categoria com esse nome para este usuário."
    )
    |> foreign_key_constraint(:budget_id, name: :categories_budget_id_fkey)
    |> validate_number(:percentage,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100,
      message: "A porcentagem deve ser um número entre 0 e 100."
    )
    |> validate_total_percentage()
    |> apply_fixed_category_rules(category.id != nil)
    |> put_change(:budget_id, budget_id)
  end

  def validate_total_percentage(changeset) do
    budget_id = get_change(changeset, :budget_id) || get_field(changeset, :budget_id)
    current_percentage = get_change(changeset, :percentage)

    if budget_id && current_percentage do
      category_id = changeset.data.id

      query =
        from(c in PersonalFinance.Finance.Category,
          where: c.budget_id == ^budget_id,
          select: c.percentage
        )

      query =
        if category_id do
          from(c in query, where: c.id != ^category_id)
        else
          query
        end

      existing_percentages =
        PersonalFinance.Repo.all(query)

      total_percentage = Enum.sum(existing_percentages) + current_percentage

      if total_percentage > 100.0 do
        add_error(
          changeset,
          :percentage,
          "A soma das porcentagens de todas as categorias não pode exceder 100%."
        )
      else
        changeset
      end
    else
      changeset
    end
  end

  defp apply_fixed_category_rules(changeset, is_update) do
    if is_update && get_field(changeset, :is_fixed) do
      changeset
      |> validate_fixed_field(:name, "O nome de categorias fixas não pode ser alterado.")
      |> validate_fixed_field(
        :description,
        "A descrição de categorias fixas não pode ser alterada."
      )
    else
      changeset
    end
  end

  defp validate_fixed_field(changeset, field, message) do
    if get_change(changeset, field) do
      add_error(changeset, field, message)
    else
      changeset
    end
  end
end
