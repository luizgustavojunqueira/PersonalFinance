defmodule PersonalFinance.Finance.RecurringEntry do
  use Ecto.Schema
  import Ecto.Changeset
  alias PersonalFinance.Finance.{Ledger, Category, Profile}

  schema "recurring_entries" do
    field :description, :string
    field :amount, :float
    field :value, :float
    field :start_date, :utc_datetime
    field :start_date_input, :date, virtual: true
    field :end_date, :utc_datetime
    field :end_date_input, :date, virtual: true
    field :frequency, Ecto.Enum, values: [:monthly, :yearly], default: :monthly
    field :type, Ecto.Enum, values: [:income, :expense], default: :expense
    field :is_active, :boolean, default: true

    belongs_to :ledger, Ledger
    belongs_to :category, Category
    belongs_to :profile, Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(recurring_entry, attrs, ledger_id) do
    recurring_entry
    |> cast(attrs, [
      :description,
      :amount,
      :value,
      :start_date_input,
      :end_date_input,
      :frequency,
      :type,
      :is_active,
      :profile_id,
      :category_id
    ])
    |> validate_required([
      :start_date_input,
      :frequency,
      :type,
      :is_active
    ])
    |> put_change(:ledger_id, ledger_id)
    |> convert_date_to_datetime(:start_date_input, :start_date, :day_start)
    |> convert_date_to_datetime(:end_date_input, :end_date, :day_end)
    |> validate_required(:start_date, message: "Data de início é obrigatória")
    |> validate_required(:value, message: "O valor é obrigatório")
    |> validate_number(:value, greater_than: 0, message: "O valor deve ser maior que zero")
    |> validate_required(:amount, message: "A quantidade é obrigatória")
    |> validate_number(:amount, greater_than: 0, message: "A quantidade deve ser maior que zero")
    |> validate_required(:description, message: "Descrição é obrigatória")
    |> validate_length(:description, max: 255, message: "Descrição muito longa")
  end

  defp convert_date_to_datetime(
         %Ecto.Changeset{valid?: true} = changeset,
         input,
         output,
         time
       ) do
    case get_change(changeset, input) do
      %Date{} = date ->
        time =
          case time do
            :day_start -> Time.new!(0, 0, 0)
            :day_end -> Time.new!(23, 59, 59)
          end

        datetime =
          DateTime.new!(date, time, "Etc/UTC")
          |> DateTime.truncate(:second)

        changeset
        |> put_change(output, datetime)

      nil ->
        changeset

      _ ->
        changeset
    end
  end

  defp convert_date_to_datetime(changeset, _, _, _), do: changeset
end
