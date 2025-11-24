defmodule PersonalFinance.Finance.RecurringEntry do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PersonalFinanceWeb.Gettext
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
      :is_active
    ])
    |> put_change(:ledger_id, ledger_id)
    |> convert_date_to_datetime(:start_date_input, :start_date, :day_start)
    |> convert_date_to_datetime(:end_date_input, :end_date, :day_end)
    |> validate_required(:start_date_input, message: gettext("Start date is required."))
    |> validate_required(:start_date, message: gettext("Start date is required."))
    |> validate_required(:frequency, message: gettext("Frequency is required."))
    |> validate_inclusion(:frequency, [:monthly, :yearly], message: gettext("Invalid frequency."))
    |> validate_required(:type, message: gettext("Type is required."))
    |> validate_inclusion(:type, [:income, :expense], message: gettext("Invalid type."))
    |> validate_required(:value, message: gettext("Value is required."))
    |> validate_number(:value,
      greater_than: 0,
      message: gettext("Value must be greater than zero.")
    )
    |> validate_required(:amount, message: gettext("Amount is required."))
    |> validate_number(:amount,
      greater_than: 0,
      message: gettext("Amount must be greater than zero.")
    )
    |> validate_required(:description, message: gettext("Description is required."))
    |> validate_length(:description, max: 255, message: gettext("Description is too long."))
    |> validate_end_date_after_start_date()
  end

  def toggle_status_changeset(recurring_entry) do
    recurring_entry
    |> change()
    |> put_change(:is_active, !recurring_entry.is_active)
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
        |> put_change(output, nil)

      "" ->
        changeset
        |> put_change(output, nil)

      _ ->
        changeset
    end
  end

  defp convert_date_to_datetime(changeset, _input, output, _time) do
    if output == :end_date do
      case get_field(changeset, :end_date_input) do
        nil -> put_change(changeset, output, nil)
        "" -> put_change(changeset, output, nil)
        _ -> changeset
      end
    else
      changeset
    end
  end

  defp validate_end_date_after_start_date(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    case {start_date, end_date} do
      {%DateTime{} = start_dt, %DateTime{} = end_dt} ->
        if DateTime.compare(end_dt, start_dt) == :lt do
          add_error(
            changeset,
            :end_date_input,
            gettext("End date must be after the start date.")
          )
        else
          changeset
        end

      _ ->
        changeset
    end
  end
end
