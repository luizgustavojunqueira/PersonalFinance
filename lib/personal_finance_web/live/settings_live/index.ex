defmodule PersonalFinanceWeb.SettingsLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope

    budget = Finance.get_budget(current_scope, params["id"])

    if budget == nil do
      {:ok,
       socket
       |> put_flash(:error, "Orçamento não encontrado.")
       |> push_navigate(to: ~p"/budgets")}
    else
      socket =
        socket
        |> assign(page_title: "Configurações", budget: budget)

      {:ok, socket}
    end
  end
end
