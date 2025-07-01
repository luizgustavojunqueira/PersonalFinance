defmodule PersonalFinanceWeb.BudgetsLive.Index do
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    user_budgets = Finance.list_budgets_for_user(current_user)

    socket = socket |> assign(budgets: user_budgets, budget_id: nil)

    {:ok, socket}
  end
end
