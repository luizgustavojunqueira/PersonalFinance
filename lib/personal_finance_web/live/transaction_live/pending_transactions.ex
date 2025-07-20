defmodule PersonalFinanceWeb.TransactionLive.PendingTransactions do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.CurrencyUtils
  alias PersonalFinance.DateUtils
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
       pending_recurrent_transactions: pending_recurrent_transactions,
       page_title: "Transações Pendentes",
       form: to_form(%{}, as: :months)
     )}
  end

  @impl true
  def handle_event("confirm_transaction", %{"id" => id}, socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope

    IO.inspect(id, label: "Confirming transaction with ID")

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
    <div class="fixed z-50 top-0 left-0 w-full h-full">
      <div
        class="fixed top-0 right-0 h-full w-148 bg-base-200 shadow-lg p-6 flex flex-col z-50"
        phx-mounted={
          JS.transition(
            {"transition-all ease-out duration-300", "translate-x-full", "translate-x-0"},
            time: 300
          )
        }
        phx-remove={
          JS.transition(
            {"transition-all ease-out duration-300", "translate-x-0", "translate-x-full"},
            time: 300
          )
        }
      >
        <div class="flex justify-between items-center mb-6">
          <h3 class="text-xl font-bold">Próximas Transações Recorrentes</h3>
          <.button
            variant="custom"
            phx-click="toggle_pending_transactions_drawer"
            class="btn btn-square"
          >
            <.icon name="hero-x-mark" class="w-10 h-10" />
          </.button>
        </div>

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
              large={false}
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
              <:col :let={transaction} label="Ações">
                <.link
                  class="text-blue-600 hover:text-blue-800"
                  phx-click="confirm_transaction"
                  phx-value-id={transaction.recurring_entry.id}
                  phx-target={@myself}
                >
                  <.icon name="hero-check" class="inline-block mr-1" />
                </.link>
              </:col>
            </.table>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
