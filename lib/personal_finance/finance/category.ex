defmodule PersonalFinance.Finance.Category do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  use Gettext, backend: PersonalFinanceWeb.Gettext

  schema "categories" do
    field :name, :string
    field :description, :string
    field :percentage, :float, default: 0.0
    field :is_default, :boolean, default: false
    field :is_fixed, :boolean, default: false
    field :color, :string, default: "#000000"
    field :is_investment, :boolean, default: false
    belongs_to :ledger, PersonalFinance.Finance.Ledger

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs, ledger_id) do
    category
    |> cast(attrs, [
      :name,
      :description,
      :percentage,
      :is_default,
      :is_fixed,
      :color,
      :is_investment
    ])
    |> validate_required([:name], message: gettext("Name is required."))
    |> validate_required([:description], message: gettext("Description is required."))
    |> validate_required([:percentage], message: gettext("Percentage is required."))
    |> validate_required([:is_default])
    |> validate_length(:name,
      min: 1,
      max: 100,
      message: gettext("Name must be between 1 and 100 characters.")
    )
    |> validate_length(:description,
      max: 500,
      message: gettext("Description must be at most 500 characters.")
    )
    |> validate_inclusion(:is_default, [true, false])
    |> unique_constraint(:is_default,
      name: :unique_default_category_per_ledger,
      where: "is_default = true"
    )
    |> unique_constraint(:name,
      name: :categories_name_ledger_id_index,
      message: gettext("A category with this name already exists for this ledger.")
    )
    |> foreign_key_constraint(:ledger_id, name: :categories_ledger_id_fkey)
    |> validate_number(:percentage,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100,
      message: gettext("Percentage must be between 0 and 100.")
    )
    |> validate_total_percentage()
    |> apply_fixed_category_rules(category.id != nil)
    |> put_change(:ledger_id, ledger_id)
  end

  def validate_total_percentage(changeset) do
    ledger_id = get_change(changeset, :ledger_id) || get_field(changeset, :ledger_id)
    current_percentage = get_change(changeset, :percentage)

    if ledger_id && current_percentage do
      category_id = changeset.data.id

      query =
        from(c in PersonalFinance.Finance.Category,
          where: c.ledger_id == ^ledger_id,
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
          gettext("The total percentage for all categories cannot exceed 100%.")
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
      |> validate_fixed_field(:name, gettext("Fixed category names cannot be changed."))
      |> validate_fixed_field(
        :description,
        gettext("Fixed category descriptions cannot be changed.")
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
