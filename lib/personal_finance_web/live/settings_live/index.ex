defmodule PersonalFinanceWeb.SettingsLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Accounts.User
  alias PersonalFinance.Finance

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
      if ledger.owner_id != current_scope.user.id do
        {:ok,
         socket
         |> put_flash(:error, "Página não encontrada.")
         |> push_navigate(to: ~p"/ledgers")}
      else
        socket =
          socket
          |> assign(page_title: "Configurações", ledger: ledger)

        {:ok, socket}
      end
    end
  end

  @impl true
  def handle_info({:user_added, %User{} = user}, socket) do
    Phoenix.LiveView.send_update(PersonalFinanceWeb.SettingsLive.CollaboratorsList,
      id: "collaborators-list"
    )

    {:noreply, socket |> put_flash(:info, "Colaborador #{user.email} adicionado com sucesso.")}
  end

  @impl true
  def handle_info({:user_removed, _user}, socket) do
    {:noreply, socket |> put_flash(:info, "Colaborador removido com sucesso.")}
  end

  @impl true
  def handle_info({:error, messsage}, socket) do
    {:noreply, socket |> put_flash(:error, messsage)}
  end
end
