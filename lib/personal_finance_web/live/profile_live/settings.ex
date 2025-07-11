defmodule PersonalFinanceWeb.ProfileLive.Settings do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance

  @impl true
  def mount(params, _session, socket) do
    budget = Finance.get_budget(socket.assigns.current_scope, params["id"])

    if budget == nil do
      {:ok,
       socket
       |> put_flash(:error, "Orçamento não encontrado.")
       |> push_navigate(to: ~p"/budgets")}
    else
      Finance.subscribe_finance(:profile, budget.id)

      profile = Finance.get_profile(socket.assigns.current_scope, budget.id, params["profile_id"])

      if profile == nil do
        {:ok,
         socket
         |> put_flash(:error, "Perfil não encontrado.")
         |> push_navigate(to: ~p"/budgets/#{budget.id}/profiles")}
      else
        {:ok,
         socket
         |> assign(budget: budget, profile: profile)}
      end
    end
  end
end
