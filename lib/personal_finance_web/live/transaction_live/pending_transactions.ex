defmodule PersonalFinanceWeb.TransactionLive.PendingTransactions do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Utils.CurrencyUtils
  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Finance

  @impl true
  def update(assigns, socket) do
    ledger = Map.get(assigns, :ledger) || socket.assigns.ledger
    current_scope = Map.get(assigns, :current_scope) || socket.assigns.current_scope

    pending_recurrent_transactions =
      Finance.list_pending_recurrent_transactions(current_scope, ledger.id, 1)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       form: to_form(%{}, as: :months),
       pending_recurrent_transactions: pending_recurrent_transactions,
       page_title: "Transações Pendentes"
     )}
  end

  @impl true
  def handle_event("confirm_transaction", %{"id" => id}, socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope

    case Finance.confirm_recurring_transaction(current_scope, ledger, id) do
      {:ok, _transaction} ->
        pending_recurrent_transactions =
          Finance.list_pending_recurrent_transactions(
            current_scope,
            ledger.id,
            socket.assigns.form[:months].value || 1
          )

        {:noreply,
         socket
         |> assign(pending_recurrent_transactions: pending_recurrent_transactions)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Erro ao confirmar transação recorrente.")}
    end
  end

  @impl true
  def handle_event("update_months", %{"months" => months}, socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope

    months = String.to_integer(months)

    pending_recurrent_transactions =
      Finance.list_pending_recurrent_transactions(current_scope, ledger.id, months)

    {:noreply,
     socket
     |> assign(pending_recurrent_transactions: pending_recurrent_transactions)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.side_modal
        id="recurring_entries_drawer"
        show={@show}
        on_close={JS.push("close_modal")}
      >
        <:title>Próximas Transações recorrentes</:title>

        <div class="mb-4">
          <.form for={@form} class="mt-1" phx-change="update_months" phx-target={@myself}>
            <.input
              field={@form[:months]}
              type="select"
              id="months"
              name="months"
              options={1..12}
              value={@form[:months].value || 1}
              class="w-full"
              label="Meses a exibir"
            />
          </.form>
        </div>

        <div class="flex-grow overflow-y-auto">
          <%= if @pending_recurrent_transactions == [] do %>
            <p class="text-gray-500">Nenhuma transação pendente.</p>
          <% else %>
            <.table
              id="pending_transactions_table"
              rows={@pending_recurrent_transactions}
            >
              <:col :let={transaction} label="Descrição">
                {transaction.description}
              </:col>
              <:col :let={transaction} label="Perfil">
                {transaction.profile.name}
              </:col>
              <:col :let={transaction} label="Tipo">
                {if transaction.type == :expense, do: "Despesa", else: "Receita"}
              </:col>
              <:col :let={transaction} label="Valor">
                {CurrencyUtils.format_money(transaction.value)}
              </:col>
              <:col :let={transaction} label="Data Prevista">
                {DateUtils.format_date(transaction.date_expected)}
              </:col>
              <:action :let={transaction}>
                <.link
                  class="text-blue-600 hover:text-blue-800"
                  phx-click="confirm_transaction"
                  phx-value-id={transaction.recurring_entry.id}
                  phx-target={@myself}
                >
                  <.icon name="hero-check" class="inline-block mr-1" />
                </.link>
              </:action>
            </.table>
          <% end %>
        </div>
      </.side_modal>
    </div>
    """
  end
end
