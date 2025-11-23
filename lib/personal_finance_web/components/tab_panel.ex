defmodule PersonalFinanceWeb.Components.TabPanel do
  use PersonalFinanceWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:tabs, [])
     |> assign(:active_tab, nil)
     |> assign(:tabs_loaded, MapSet.new())}
  end

  @impl true
  def update(%{tabs: tabs} = assigns, socket) when is_list(tabs) and tabs != [] do
    assigns =
      assigns
      |> Map.put_new(:wrapper_class, nil)
      |> Map.put_new(:tabs_class, nil)
      |> Map.put_new(:panes_class, nil)
      |> Map.put_new(:preload_tabs, [])

    prepared_tabs = Enum.map(tabs, &prepare_tab/1)
    active_tab = resolve_active_tab(assigns, socket, prepared_tabs)
    tabs_loaded = update_tabs_loaded(assigns, socket, active_tab, prepared_tabs)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:tabs, prepared_tabs)
     |> assign(:active_tab, active_tab)
     |> assign(:tabs_loaded, tabs_loaded)}
  end

  def update(_assigns, _socket) do
    raise ArgumentError, "TabPanel requires a non-empty :tabs assign"
  end

  @impl true
  def handle_event("navigate_tab", %{"tab" => tab_id}, socket) do
    case find_tab(socket.assigns.tabs, tab_id) do
      nil ->
        {:noreply, socket}

      tab ->
        tabs_loaded = MapSet.put(socket.assigns.tabs_loaded, tab.id)

        {:noreply,
         socket
         |> assign(:active_tab, tab.id)
         |> assign(:tabs_loaded, tabs_loaded)}
    end
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class={["flex flex-col", @wrapper_class]}>
      <div
        role="tablist"
        class={["flex flex-wrap gap-2 border-b border-base-300 p-0", @tabs_class]}
      >
        <%= for tab <- @tabs do %>
          <button
            type="button"
            role="tab"
            class={
              [
                "tab px-4 py-2 rounded-t-lg text-sm font-medium transition bg-base-200",
                tab_active?(tab, @active_tab) && "bg-base-300 text-base-content shadow-inner"
              ]
            }
            phx-click="navigate_tab"
            phx-target={@myself}
            phx-value-tab={tab.id}
            disabled={tab.disabled}
          >
            <%= if tab.icon do %>
              <.icon name={tab.icon} class="w-4 h-4 mr-2" />
            <% end %>
            {tab.label}
            <%= if tab.badge do %>
              <span class="badge badge-sm ml-2">{tab.badge}</span>
            <% end %>
          </button>
        <% end %>
      </div>

      <div class={["bg-base-200/80 rounded-b-xl rounded-tr-xl p-4", @panes_class]}>
        <%= for tab <- @tabs do %>
          <div
            id={tab_dom_id(@id, tab.id)}
            class={["tab-pane", tab.id != @active_tab && "hidden"]}
            role="tabpanel"
            aria-labelledby={"#{@id}-btn-#{tab.id}"}
          >
            <%= if MapSet.member?(@tabs_loaded, tab.id) do %>
              <.live_component
                module={tab.component}
                id={tab.component_id || tab_component_dom_id(@id, tab.id)}
                {Map.get(tab, :assigns, %{})}
              />
            <% else %>
              <% label_text = tab.label |> to_string() %>
              <div class="flex flex-col items-center justify-center gap-3 py-12 text-sm text-base-content/60">
                <span class="loading loading-dots loading-md text-primary"></span>
                <span>Carregando {String.downcase(label_text)}...</span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp prepare_tab(%{id: id, label: _label, component: _component} = tab) when is_atom(id) do
    defaults = %{
      component_id: nil,
      icon: nil,
      badge: nil,
      assigns: %{},
      disabled: false
    }

    Map.merge(defaults, tab, fn _key, _default, current -> current end)
  end

  defp prepare_tab(_tab) do
    raise ArgumentError,
          "Each tab entry must include :id (atom), :label, and :component keys"
  end

  defp resolve_active_tab(_assigns, socket, []), do: socket.assigns[:active_tab]

  defp resolve_active_tab(assigns, socket, tabs) do
    candidates = [assigns[:active_tab], socket.assigns[:active_tab], assigns[:initial_tab]]

    case Enum.find_value(candidates, fn candidate ->
           case fetch_tab(tabs, candidate) do
             {:ok, tab} -> tab.id
             :error -> nil
           end
         end) do
      nil ->
        tabs |> List.first() |> Map.get(:id)

      id ->
        id
    end
  end

  defp update_tabs_loaded(assigns, socket, active_tab, tabs) do
    base = socket.assigns[:tabs_loaded] || MapSet.new()

    preload_set =
      assigns
      |> Map.get(:preload_tabs, [])
      |> List.wrap()
      |> Enum.reduce(MapSet.new(), fn tab_id, acc ->
        case find_tab(tabs, tab_id) do
          nil -> acc
          tab -> MapSet.put(acc, tab.id)
        end
      end)

    base
    |> MapSet.union(preload_set)
    |> then(fn set ->
      if active_tab, do: MapSet.put(set, active_tab), else: set
    end)
  end

  defp find_tab(tabs, tab_id) when is_atom(tab_id) do
    Enum.find(tabs, &(&1.id == tab_id))
  end

  defp find_tab(tabs, tab_id) when is_binary(tab_id) do
    Enum.find(tabs, &(to_string(&1.id) == tab_id))
  end

  defp find_tab(_tabs, _), do: nil

  defp fetch_tab(_tabs, nil), do: :error

  defp fetch_tab(tabs, tab_id) do
    case find_tab(tabs, tab_id) do
      nil -> :error
      tab -> {:ok, tab}
    end
  end

  defp tab_active?(tab, active_tab), do: tab.id == active_tab

  defp tab_dom_id(base, tab_id), do: "#{base}-tab-#{tab_id}"

  defp tab_component_dom_id(base, tab_id), do: "#{base}-component-#{tab_id}"
end
