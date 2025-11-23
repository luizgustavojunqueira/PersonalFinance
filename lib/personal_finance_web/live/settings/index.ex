defmodule PersonalFinanceWeb.SettingsLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Category
  alias PersonalFinance.Finance.Profile
  alias PersonalFinanceWeb.CategoryLive.CategoriesPanel
  alias PersonalFinanceWeb.SettingsLive.ProfilesPanel

  @categories_panel_id "settings-categories"
  @profiles_panel_id "settings-profiles"

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
        Finance.subscribe_finance(:profile, ledger.id)

        socket =
          socket
          |> assign(page_title: "Configurações", ledger: ledger)
          |> assign(:categories_panel_id, @categories_panel_id)
          |> assign(:profiles_panel_id, @profiles_panel_id)

        {:ok, socket}
      end
    end
  end

  @impl true
  def handle_info({:saved, %Category{} = category}, socket) do
    send_update(CategoriesPanel,
      id: socket.assigns.categories_panel_id,
      action: :saved,
      category: category
    )

    {:noreply, put_flash(socket, :info, "Categoria salva com sucesso.")}
  end

  @impl true
  def handle_info({:deleted, %Category{} = category}, socket) do
    send_update(CategoriesPanel,
      id: socket.assigns.categories_panel_id,
      action: :deleted,
      category: category
    )

    {:noreply, put_flash(socket, :info, "Categoria removida com sucesso.")}
  end

  @impl true
  def handle_info({:saved, %Profile{} = profile}, socket) do
    send_update(ProfilesPanel,
      id: socket.assigns.profiles_panel_id,
      action: :profile_saved,
      profile: profile,
      ledger: socket.assigns.ledger,
      current_scope: socket.assigns.current_scope,
      parent_pid: self()
    )

    {:noreply, put_flash(socket, :info, "Perfil salvo com sucesso.")}
  end

  @impl true
  def handle_info({:deleted, %Profile{} = profile}, socket) do
    send_update(ProfilesPanel,
      id: socket.assigns.profiles_panel_id,
      action: :profile_deleted,
      profile: profile,
      ledger: socket.assigns.ledger,
      current_scope: socket.assigns.current_scope,
      parent_pid: self()
    )

    {:noreply, put_flash(socket, :info, "Perfil removido com sucesso.")}
  end

  @impl true
  def handle_info({:put_flash, type, message}, socket) when type in [:info, :error] do
    {:noreply, put_flash(socket, type, message)}
  end
end
