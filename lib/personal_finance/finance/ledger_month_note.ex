defmodule PersonalFinance.Finance.LedgerMonthNote do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PersonalFinanceWeb.Gettext

  schema "ledger_month_notes" do
    field :year, :integer
    field :month, :integer
    field :content, :string, default: nil

    belongs_to :ledger, PersonalFinance.Finance.Ledger

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(%__MODULE__{} = note, attrs) do
    note
    |> cast(attrs, [:year, :month, :content, :ledger_id])
    |> validate_required([:year, :month, :ledger_id],
      message: gettext("This field is required.")
    )
    |> validate_inclusion(:month, 1..12,
      message: gettext("Month must be between 1 and 12.")
    )
    |> validate_number(:year,
      greater_than_or_equal_to: 1900,
      less_than_or_equal_to: 3000,
      message: gettext("Year must be between 1900 and 3000.")
    )
    |> validate_length(:content,
      max: 4000,
      message: gettext("Notes must be at most 4000 characters.")
    )
    |> unique_constraint([:ledger_id, :year, :month],
      name: :ledger_month_notes_ledger_year_month_index,
      message: gettext("A note for this month already exists for this ledger.")
    )
  end
end
