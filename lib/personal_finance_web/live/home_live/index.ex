defmodule PersonalFinanceWeb.HomeLive.Index do
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(%{"id" => budget_id}, _session, socket) do
    current_scope = socket.assigns.current_scope
    budget = Finance.get_budget!(current_scope, budget_id)
    transactions = Finance.list_transactions(current_scope, budget)

    categories = Finance.list_categories(current_scope, budget)

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
        current_user: current_scope.user,
        budget: budget,
        page_title: "Home #{budget.name}",
        show_welcome_message: true,
        labels: labels,
        values: values
      )

    {:ok, socket}
  end
end
