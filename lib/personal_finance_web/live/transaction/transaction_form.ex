defmodule PersonalFinanceWeb.TransactionLive.TransactionForm do
  use PersonalFinanceWeb, :live_component
  alias PersonalFinance.Utils.ParseUtils
  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Transaction

  @impl true
  def update(assigns, socket) do
    ledger = assigns.ledger
    current_scope = assigns.current_scope

    transaction =
      assigns.transaction || %Transaction{ledger_id: ledger.id}

    changeset =
      Finance.change_transaction(
        current_scope,
        transaction,
        ledger,
        %{}
      )

    formatted_value = ParseUtils.format_float_for_input(changeset.data.value)
    formatted_amount = ParseUtils.format_float_for_input(changeset.data.amount)

    changeset =
      changeset
      |> Ecto.Changeset.put_change(:value, formatted_value)
      |> Ecto.Changeset.put_change(:amount, formatted_amount)
      |> maybe_set_current_datetime(assigns.action)

    investment_category = Finance.get_investment_category(current_scope, ledger.id)

    socket =
      socket
      |> assign(assigns)
      |> assign(
        form: to_form(changeset, as: :transaction),
        selected_category_id: assigns.transaction && assigns.transaction.category_id,
        investment_category_id: if(investment_category, do: investment_category.id, else: nil)
      )

    {:ok, socket}
  end

  defp maybe_set_current_datetime(changeset, :new) do
    now_utc = DateTime.utc_now()
    local_datetime = PersonalFinance.Utils.DateUtils.to_local_time_with_date(now_utc)
    current_date = NaiveDateTime.to_date(local_datetime)
    current_time = NaiveDateTime.to_time(local_datetime)
    current_time = %Time{current_time | second: 0, microsecond: {0, 0}}

    changeset
    |> Ecto.Changeset.put_change(:date_input, current_date)
    |> Ecto.Changeset.put_change(:time_input, current_time)
  end

  defp maybe_set_current_datetime(changeset, :edit) do
    case Ecto.Changeset.get_field(changeset, :date) do
      %DateTime{} = datetime ->
        local_datetime = PersonalFinance.Utils.DateUtils.to_local_time_with_date(datetime)
        local_date = NaiveDateTime.to_date(local_datetime)
        local_time = NaiveDateTime.to_time(local_datetime)

        changeset
        |> Ecto.Changeset.put_change(:date_input, local_date)
        |> Ecto.Changeset.put_change(:time_input, local_time)

      _ ->
        changeset
    end
  end

  # Para outros casos, não faz nada
  defp maybe_set_current_datetime(changeset, _), do: changeset

  @impl true
  def handle_event("validate", %{"transaction" => transaction_params}, socket) do
    value = Map.get(transaction_params, "value") |> ParseUtils.parse_float()
    amount = Map.get(transaction_params, "amount") |> ParseUtils.parse_float()
    total_value = value * amount

    params =
      Map.put(transaction_params, "total_value", total_value)

    new_selected_category_id =
      Map.get(transaction_params, "category_id") || socket.assigns.selected_category_id

    changeset =
      Finance.change_transaction(
        socket.assigns.current_scope,
        socket.assigns.transaction || %Transaction{ledger_id: socket.assigns.ledger.id},
        socket.assigns.ledger,
        params
      )
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket,
       form: to_form(changeset, as: :transaction),
       selected_category_id: new_selected_category_id
     )}
  end

  @impl true
  def handle_event("save", %{"transaction" => transaction_params}, socket) do
    value = Map.get(transaction_params, "value") |> ParseUtils.parse_float()
    amount = Map.get(transaction_params, "amount") |> ParseUtils.parse_float()
    total_value = value * amount
    params = Map.put(transaction_params, "total_value", total_value)

    action = socket.assigns.action

    case save_transaction(socket, action, params) do
      {:ok, transaction} ->
        send(self(), {:saved, transaction})
        {:noreply, assign(socket, show: false)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :transaction))}
    end
  end

  defp save_transaction(socket, :new, params) do
    Finance.create_transaction(
      socket.assigns.current_scope,
      params,
      socket.assigns.ledger
    )
  end

  defp save_transaction(socket, :edit, params) do
    Finance.update_transaction(
      socket.assigns.current_scope,
      socket.assigns.transaction,
      params
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal
        show={@show}
        id={@id}
        on_close={JS.push("close_modal")}
        class="mt-2"
      >
        <:title>{if @action == :edit, do: gettext("Edit Transaction"), else: gettext("New Transaction")}</:title>
        <.form
          for={@form}
          id="transaction-form"
          phx-submit="save"
          phx-change="validate"
          phx-target={@myself}
        >
          <div class="space-y-6">
            <div class="rounded-2xl border border-base-300 bg-base-100/80 p-5 space-y-4">
              <.input
                field={@form[:description]}
                id="input-description"
                type="text"
                label={gettext("Description")}
                placeholder={gettext("E.g.: Monster")}
              />

              <div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:profile_id]}
                  id="input-profile"
                  type="select"
                  options={@profiles}
                  label={gettext("Profile")}
                />
                <.input
                  field={@form[:type]}
                  id="input-type"
                  type="select"
                  label={gettext("Type")}
                  options={[{gettext("Income"), :income}, {gettext("Expense"), :expense}]}
                />
              </div>

              <div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:category_id]}
                  id="input-category"
                  type="select"
                  options={@categories}
                  label={gettext("Category")}
                />

                <%= if @selected_category_id && to_string(@selected_category_id) == to_string(@investment_category_id) do %>
                  <div
                    class="w-full"
                    phx-mounted={
                      JS.transition(
                        {"transition-all transform ease-in", "opacity-0 max-w-0",
                         "opacity-100 max-w-full"},
                        time: 200
                      )
                    }
                    phx-remove={
                      JS.hide(
                        transition:
                          {"transition-all transform ease-in duration-200",
                           "opacity-100 max-w-full",
                           "opacity-0 max-w-0"}
                      )
                    }
                  >
                    <.input
                      field={@form[:investment_type_id]}
                      id="input-investment-type"
                      type="select"
                      options={@investment_types}
                      label={gettext("Investment Type")}
                    />
                  </div>
                <% else %>
                  <div class="w-full hidden sm:block"></div>
                <% end %>
              </div>
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <div class="rounded-2xl border border-base-300 bg-base-100/80 p-5 space-y-4">
                <.input
                  field={@form[:amount]}
                  id="input-amount"
                  type="number"
                  step="0.00000001"
                  label={gettext("Amount")}
                  placeholder={gettext("E.g.: 1")}
                />
                <.input
                  field={@form[:value]}
                  id="input-value"
                  type="number"
                  step="0.01"
                  label={gettext("Value")}
                  placeholder={gettext("E.g.: 10.00")}
                />
              </div>

              <div class="rounded-2xl border border-base-300 bg-base-100/80 p-5 space-y-4">
                <.input
                  field={@form[:date_input]}
                  id="input-date"
                  type="date"
                  label={gettext("Date")}
                  placeholder={gettext("E.g.: 2023-10-01")}
                />
                <.input
                  field={@form[:time_input]}
                  id="input-time"
                  type="time"
                  label={gettext("Time")}
                  placeholder={gettext("E.g.: 14:30")}
                />
              </div>
            </div>

            <div class="flex justify-end gap-2">
              <.button
                variant="primary"
                class="w-full sm:w-auto"
                phx-disable-with={gettext("Saving...")}
              >
                {gettext("Save")}
              </.button>
            </div>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end
end
