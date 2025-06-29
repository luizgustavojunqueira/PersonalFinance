defmodule PersonalFinanceWeb.HomeLive.Index do
  alias PersonalFinance.PubSub
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    user_budgets =
      Finance.list_budgets_for_user(current_user)

    current_budget =
      case user_budgets do
        [] -> nil
        [first | _] -> first
      end

    if current_user do
      Phoenix.PubSub.subscribe(
        PubSub,
        "transactions_updates:#{current_budget.id}"
      )
    end

    transactions = Finance.list_transactions_for_budget(current_budget)

    categories = Finance.list_categories_for_budget(current_budget)

    labels =
      Enum.map(categories, fn category ->
        category.name
      end)

    values =
      Enum.map(categories, fn category ->
        Finance.get_total_value_by_category(category.id, transactions)
      end)

    socket =
      socket
      |> assign(
        current_user: current_user,
        current_budget: current_budget,
        page_title: "Home",
        show_welcome_message: true,
        labels: labels,
        values: values
      )

    {:ok, socket}
  end

  @impl true
  def handle_info({:transaction_changed, budget_id}, socket)
      when budget_id == socket.assigns.current_budget.id do
    transactions = Finance.list_transactions_for_budget(socket.assigns.current_budget)

    categories = Finance.list_categories_for_budget(socket.assigns.current_budget)

    labels =
      Enum.map(categories, fn category ->
        category.name
      end)

    values =
      Enum.map(categories, fn category ->
        Finance.get_total_value_by_category(category.id, transactions)
      end)

    socket =
      socket
      |> assign(
        labels: labels,
        values: values
      )

    {:noreply, socket}
  end
end
