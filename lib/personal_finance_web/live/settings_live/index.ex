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
      if budget.owner_id != current_scope.user.id do
        {:ok,
         socket
         |> put_flash(:error, "Página não encontrada.")
         |> push_navigate(to: ~p"/budgets")}
      else
        socket =
          socket
          |> assign(page_title: "Configurações", budget: budget)

        {:ok, socket}
      end
    end
  end

  @impl true
  def handle_info({:invite_sent, _invite}, socket) do
    Phoenix.LiveView.send_update(PersonalFinanceWeb.SettingsLive.CollaboratorsList,
      id: "collaborators-list"
    )

    {:noreply, socket |> put_flash(:info, "Convite enviado com sucesso.")}
  end

  @impl true
  def handle_info({:user_removed, _user}, socket) do
    {:noreply, socket |> put_flash(:info, "Colaborador removido com sucesso.")}
  end
end
