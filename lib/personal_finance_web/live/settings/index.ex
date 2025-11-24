defmodule PersonalFinanceWeb.SettingsLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Category
  alias PersonalFinance.Finance.Profile
  alias PersonalFinanceWeb.CategoryLive.CategoriesPanel
  alias PersonalFinanceWeb.SettingsLive.AccessPanel
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
       |> put_flash(:error, gettext("Ledger not found."))
       |> push_navigate(to: ~p"/ledgers")}
    else
      if ledger.owner_id != current_scope.user.id do
        {:ok,
         socket
         |> put_flash(:error, gettext("Page not found."))
         |> push_navigate(to: ~p"/ledgers")}
      else
        Finance.subscribe_finance(:category, ledger.id)
        Finance.subscribe_finance(:profile, ledger.id)

        tabs = build_settings_tabs(ledger, current_scope, self())
        default_tab = tabs |> List.first() |> Map.get(:id)

        socket =
          socket
          |> assign(page_title: gettext("Settings"), ledger: ledger)
          |> assign(:categories_panel_id, @categories_panel_id)
          |> assign(:profiles_panel_id, @profiles_panel_id)
          |> assign(:settings_tabs, tabs)
          |> assign(:tab_metadata, tab_metadata(tabs))
          |> assign(:active_settings_tab, default_tab)
          |> assign(:tab_panel_parent, self())

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

    {:noreply, put_flash(socket, :info, gettext("Category successfully saved."))}
  end

  @impl true
  def handle_info({:deleted, %Category{} = category}, socket) do
    send_update(CategoriesPanel,
      id: socket.assigns.categories_panel_id,
      action: :deleted,
      category: category
    )

    {:noreply, put_flash(socket, :info, gettext("Category successfully deleted."))}
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

    {:noreply, put_flash(socket, :info, gettext("Profile successfully saved."))}
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

    {:noreply, put_flash(socket, :info, gettext("Profile successfully deleted."))}
  end

  @impl true
  def handle_info({:put_flash, type, message}, socket) when type in [:info, :error] do
    {:noreply, put_flash(socket, type, message)}
  end

  def handle_info({:tab_panel_changed, "settings-tabs", tab_id}, socket) do
    {:noreply, assign(socket, :active_settings_tab, tab_id)}
  end

  defp build_settings_tabs(ledger, current_scope, parent_pid) do
    [
      %{
        id: :categories,
        label: gettext("Categories"),
        icon: "hero-tag",
        component: CategoriesPanel,
        component_id: @categories_panel_id,
        assigns: %{
          ledger: ledger,
          current_scope: current_scope
        },
        hero_tagline: gettext("Categories"),
        hero_description: gettext("Classify your expenses and control allocation caps.")
      },
      %{
        id: :profiles,
        label: gettext("Profiles"),
        icon: "hero-users",
        component: ProfilesPanel,
        component_id: @profiles_panel_id,
        assigns: %{
          ledger: ledger,
          current_scope: current_scope,
          parent_pid: parent_pid
        },
        hero_tagline: gettext("Profiles & recurrences"),
        hero_description: gettext("Organize recurring entries with color-coded personas.")
      },
      %{
        id: :access,
        label: gettext("Access"),
        icon: "hero-user-group",
        component: AccessPanel,
        assigns: %{
          ledger: ledger,
          current_scope: current_scope,
          parent_pid: parent_pid
        },
        hero_tagline: gettext("Access control"),
        hero_description: gettext("Invite collaborators and manage permissions in real time.")
      }
    ]
  end

  defp tab_metadata(tabs) do
    Enum.reduce(tabs, %{}, fn tab, acc ->
      Map.put(acc, tab.id, %{
        label: tab.label,
        tagline: Map.get(tab, :hero_tagline, tab.label),
        description: Map.get(tab, :hero_description)
      })
    end)
  end
end
