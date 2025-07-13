defmodule PersonalFinanceWeb.HomeLive.Index do
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope
    ledger = Finance.get_ledger(current_scope, params["id"])

    if ledger == nil do
      {:ok,
       socket
       |> put_flash(:error, "Orçamento não encontrado.")
       |> push_navigate(to: ~p"/ledgers")}
    else
      Finance.subscribe_finance(:transaction, ledger.id)
      Finance.subscribe_finance(:category, ledger.id)

      transactions = Finance.list_transactions(current_scope, ledger)
      categories = Finance.list_categories(current_scope, ledger)

      {labels, values} = calculate_chart_data(categories, transactions)

      socket =
        socket
        |> assign(
          current_user: current_scope.user,
          ledger: ledger,
          page_title: "Home #{ledger.name}",
          show_welcome_message: true,
          labels: labels,
          values: values,
          transactions: transactions,
          categories: categories
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:saved, %PersonalFinance.Finance.Transaction{} = new_transaction}, socket) do
    updated_transactions =
      Enum.map(socket.assigns.transactions, fn t ->
        if t.id == new_transaction.id, do: new_transaction, else: t
      end)

    final_transactions =
      if Enum.any?(updated_transactions, &(&1.id == new_transaction.id)) do
        updated_transactions
      else
        [new_transaction | updated_transactions]
      end

    # Recalcula os dados do gráfico
    {labels, values} = calculate_chart_data(socket.assigns.categories, final_transactions)

    {:noreply, assign(socket, transactions: final_transactions, labels: labels, values: values)}
  end

  @impl true
  def handle_info(
        {:deleted, %PersonalFinance.Finance.Transaction{} = deleted_transaction},
        socket
      ) do
    # Remove a transação da lista
    updated_transactions =
      Enum.reject(socket.assigns.transactions, fn t -> t.id == deleted_transaction.id end)

    # Recalcula os dados do gráfico
    {labels, values} = calculate_chart_data(socket.assigns.categories, updated_transactions)

    {:noreply, assign(socket, transactions: updated_transactions, labels: labels, values: values)}
  end

  @impl true
  def handle_info({:saved, %PersonalFinance.Finance.Category{} = new_category}, socket) do
    updated_categories =
      Enum.map(socket.assigns.categories, fn c ->
        if c.id == new_category.id, do: new_category, else: c
      end)

    final_categories =
      if Enum.any?(updated_categories, &(&1.id == new_category.id)) do
        updated_categories
      else
        [new_category | updated_categories]
      end

    {labels, values} = calculate_chart_data(final_categories, socket.assigns.transactions)

    {:noreply, assign(socket, categories: final_categories, labels: labels, values: values)}
  end

  @impl true
  def handle_info({:deleted, %PersonalFinance.Finance.Category{} = deleted_category}, socket) do
    # Remove a categoria da lista
    updated_categories =
      Enum.reject(socket.assigns.categories, fn c -> c.id == deleted_category.id end)

    # Recalcula os dados do gráfico
    {labels, values} = calculate_chart_data(updated_categories, socket.assigns.transactions)

    {:noreply, assign(socket, categories: updated_categories, labels: labels, values: values)}
  end

  @impl true
  def handle_info(:transactions_updated, socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger

    updated_transactions = PersonalFinance.Finance.list_transactions(current_scope, ledger)

    {labels, values} = calculate_chart_data(socket.assigns.categories, updated_transactions)

    {:noreply, assign(socket, transactions: updated_transactions, labels: labels, values: values)}
  end

  defp calculate_chart_data(categories, transactions) do
    labels =
      Enum.map(categories, fn category ->
        category.name
      end)

    values =
      Enum.map(categories, fn category ->
        Finance.get_total_value_by_category(category.id, transactions)
      end)

    {labels, values}
  end
end
