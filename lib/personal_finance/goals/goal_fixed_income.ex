defmodule PersonalFinance.Goals.GoalFixedIncome do
  use Ecto.Schema
  import Ecto.Changeset

  schema "goal_fixed_incomes" do
    belongs_to :goal, PersonalFinance.Goals.Goal
    belongs_to :fixed_income, PersonalFinance.Investment.FixedIncome
    field :allocation_percent, :float

    timestamps(type: :utc_datetime)
  end

  def changeset(goal_fixed_income, attrs) do
    goal_fixed_income
    |> cast(attrs, [:goal_id, :fixed_income_id, :allocation_percent])
    |> validate_required([:goal_id, :fixed_income_id])
    |> validate_number(:allocation_percent,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
  end
end
