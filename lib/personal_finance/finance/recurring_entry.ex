defmodule PersonalFinance.Finance.RecurringEntry do
  use Ecto.Schema
  import Ecto.Changeset
  alias PersonalFinance.Finance.{Budget, Category, Profile}

  schema "recurring_entries" do
    field :description, :string
    field :amount, :float
    field :value, :float
    field :start_date, :date
    field :end_date, :date
    field :frequency, Ecto.Enum, values: [:monthly, :yearly], default: :monthly
    field :type, Ecto.Enum, values: [:income, :expense], default: :expense
    field :is_active, :boolean, default: true

    belongs_to :budget, Budget
    belongs_to :category, Category
    belongs_to :profile, Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(recurring_entry, attrs, budget_id) do
    recurring_entry
    |> cast(attrs, [
      :description,
      :amount,
      :value,
      :start_date,
      :end_date,
      :frequency,
      :type,
      :is_active,
      :profile_id,
      :category_id
    ])
    |> validate_required([
      :amount,
      :value,
      :start_date,
      :frequency,
      :type,
      :is_active
    ])
    |> put_change(:budget_id, budget_id)
    |> validate_required(:description, message: "Descrição é obrigatória")
    |> validate_length(:description, max: 255, message: "Descrição muito longa")
  end
end
