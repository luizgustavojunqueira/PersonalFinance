defmodule PersonalFinance.Finance.CategorySuggestion do
  use Ecto.Schema
  import Ecto.Changeset

  alias PersonalFinance.Finance.{Category, Ledger}

  schema "category_suggestions" do
    field :normalized_description, :string
    field :count, :integer, default: 1

    belongs_to :ledger, Ledger
    belongs_to :category, Category

    timestamps(type: :utc_datetime)
  end

  def changeset(category_suggestion, attrs) do
    category_suggestion
    |> cast(attrs, [:normalized_description, :count, :ledger_id, :category_id])
    |> validate_required([:normalized_description, :count, :ledger_id, :category_id])
    |> validate_length(:normalized_description, max: 255)
    |> validate_number(:count, greater_than: 0)
    |> unique_constraint(:normalized_description,
      name: :category_suggestions_ledger_description_category_index,
      message: "already tracked for this category"
    )
  end
end
