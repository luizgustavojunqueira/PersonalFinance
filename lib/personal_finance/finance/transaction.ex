defmodule PersonalFinance.Finance.Transaction do
  use Ecto.Schema
  import Ecto.Changeset
  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Finance.{Category, InvestmentType, Profile, RecurringEntry}

  schema "transactions" do
    field :value, :float
    field :total_value, :float
    field :amount, :float
    field :description, :string
    field :date, :utc_datetime
    field :date_input, :date, virtual: true
    field :time_input, :time, virtual: true
    field :type, Ecto.Enum, values: [:income, :expense], default: :expense
    belongs_to :category, Category
    belongs_to :investment_type, InvestmentType
    belongs_to :profile, Profile
    belongs_to :ledger, PersonalFinance.Finance.Ledger

    belongs_to :recurring_entry, RecurringEntry, foreign_key: :recurring_entry_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs, ledger_id) do
    transaction
    |> cast(attrs, [
      :value,
      :total_value,
      :amount,
      :description,
      :date_input,
      :time_input,
      :investment_type_id,
      :category_id,
      :profile_id,
      :recurring_entry_id,
      :type
    ])
    |> validate_inclusion(:type, [:income, :expense], message: "Tipo de transação inválido")
    |> validate_required([:value], message: "O valor da transação é obrigatório")
    |> validate_required([:amount], message: "A quantidade é obrigatória")
    |> validate_required([:description], message: "A descrição é obrigatória")
    |> validate_length(:description,
      max: 255,
      message: "A descrição deve ter no máximo 255 caracteres"
    )
    |> convert_date_to_datetime(:date_input, :date)
    |> validate_required([:date], message: "A data é obrigatória")
    |> validate_required([:profile_id], message: "Selecione um perfil")
    |> put_change(:ledger_id, ledger_id)
  end

  defp convert_date_to_datetime(
         %Ecto.Changeset{valid?: true} = changeset,
         input,
         output
       ) do
    case get_change(changeset, input) do
      %Date{} = date ->
        {:ok, time} =
          case get_change(changeset, :time_input) do
            %Time{} = t -> {:ok, t}
            _ -> Time.new(0, 0, 0)
          end

        {time, date} =
          DateUtils.local_time_to_utc_with_date(time, date)

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

  defp convert_date_to_datetime(changeset, _, _), do: changeset
end
