defmodule PersonalFinanceWeb.SettingsLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Accounts.User
  alias PersonalFinance.Finance
  alias PersonalFinanceWeb.CategoryLive.CategoriesPanel

  @categories_panel_id "settings-categories"

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
        Finance.subscribe_finance(:category, ledger.id)

        socket =
          socket
          |> assign(page_title: "Configurações", ledger: ledger)
          |> assign(:categories_panel_id, @categories_panel_id)

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
    Phoenix.LiveView.send_update(PersonalFinanceWeb.SettingsLive.InviteForm,
      id: "invite-form",
      ledger: socket.assigns.ledger,
      current_scope: socket.assigns.current_scope
    )

    {:noreply, socket |> put_flash(:info, "Colaborador removido com sucesso.")}
  end

  @impl true
  def handle_info({:error, messsage}, socket) do
    {:noreply, socket |> put_flash(:error, messsage)}
  end

  @impl true
  def handle_info({:saved, category}, socket) do
    send_update(CategoriesPanel,
      id: socket.assigns.categories_panel_id,
      action: :saved,
      category: category
    )

    {:noreply, put_flash(socket, :info, "Categoria salva com sucesso.")}
  end

  @impl true
  def handle_info({:deleted, category}, socket) do
    send_update(CategoriesPanel,
      id: socket.assigns.categories_panel_id,
      action: :deleted,
      category: category
    )

    {:noreply, put_flash(socket, :info, "Categoria removida com sucesso.")}
  end
end
