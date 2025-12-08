defmodule PersonalFinance.Goals.Goal do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PersonalFinanceWeb.Gettext

  schema "goals" do
    field :name, :string
    field :description, :string
    field :target_amount, :decimal
    field :target_date, :date
    field :color, :string

    belongs_to :profile, PersonalFinance.Finance.Profile
    belongs_to :ledger, PersonalFinance.Finance.Ledger

    has_many :goal_fixed_incomes, PersonalFinance.Goals.GoalFixedIncome, on_delete: :delete_all

    many_to_many :fixed_incomes, PersonalFinance.Investment.FixedIncome,
      join_through: PersonalFinance.Goals.GoalFixedIncome,
      join_keys: [goal_id: :id, fixed_income_id: :id]

    timestamps(type: :utc_datetime)
  end

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:name, :description, :target_amount, :target_date, :color, :profile_id])
    |> validate_required(:name, message: gettext("Name is required."))
    |> validate_required(:target_amount, message: gettext("Target amount is required."))
    |> validate_number(:target_amount,
      greater_than: 0,
      message: gettext("Target amount must be greater than zero.")
    )
    |> validate_length(:name, max: 120, message: gettext("Name must be at most 120 characters."))
    |> validate_length(:description,
      max: 500,
      message: gettext("Description must be at most 500 characters.")
    )
    |> validate_length(:color, max: 20)
  end
end
