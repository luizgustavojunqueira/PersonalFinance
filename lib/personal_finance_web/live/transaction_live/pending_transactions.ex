defmodule PersonalFinanceWeb.TransactionLive.PendingTransactions do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Finance

  @impl true
  def update(assigns, socket) do
    budget = Map.get(assigns, :budget) || socket.assigns.budget
    current_scope = Map.get(assigns, :current_scope) || socket.assigns.current_scope

    pending_recurrent_transactions =
      Finance.list_pending_recurrent_transactions(current_scope, budget.id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       pending_recurrent_transactions: pending_recurrent_transactions,
       page_title: "Transações Pendentes"
     )}
  end

  @impl true
  def handle_event("confirm_transaction", %{"id" => id}, socket) do
    budget = socket.assigns.budget
    current_scope = socket.assigns.current_scope

    IO.inspect(id, label: "Confirming transaction with ID")

    case Finance.confirm_recurring_transaction(current_scope, budget, id) do
      {:ok, _transaction} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Transação recorrente confirmada com sucesso."
         )
         |> push_navigate(to: ~p"/budgets/#{budget.id}/transactions")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Erro ao confirmar transação recorrente.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="fixed top-0 right-0 h-full w-148 bg-offwhite dark:bg-gray-800 shadow-lg p-6 flex flex-col text-dark-green dark:text-offwhite z-50"
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
          phx-click="close_pending_transactions_drawer"
          class="text-gray-500 hover:text-gray-700"
        >
          <.icon name="hero-x-mark" />
        </.button>
      </div>

      <div class="flex-grow overflow-y-auto">
        <%= if @pending_recurrent_transactions == [] do %>
          <p class="text-gray-500">Nenhuma transação pendente.</p>
        <% else %>
          <.table id="pending_transactions_table" rows={@pending_recurrent_transactions}>
            <:col :let={transaction} label="Descrição">
              {transaction.description}
            </:col>
            <:col :let={transaction} label="Valor">
              {transaction.value}
            </:col>
            <:col :let={transaction} label="Data Prevista">
              {transaction.date_expected}
            </:col>
            <:col :let={transaction} label="Ações">
              <.link
                class="text-blue-600 hover:text-blue-800"
                phx-click="confirm_transaction"
                phx-value-id={transaction.recurring_entry.id}
                phx-target={@myself}
              >
                Confirmar
              </.link>
            </:col>
          </.table>
        <% end %>
      </div>
    </div>
    """
  end
end
