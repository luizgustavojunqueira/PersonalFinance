defmodule PersonalFinanceWeb.LedgersLive.LedgerCardItem do
  use PersonalFinanceWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, show_menu: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="card bg-base-100 w-96 shadow-sm"
      id={@id}
      phx-mounted={JS.transition({"ease-out duration-300", "opacity-0", "opacity-100"}, time: 300)}
    >
      <div class="card-body">
        <h2 class="card-title w-full flex justify-between items-center">
          {@ledger.name}
          <%= if @ledger.owner.id == @current_scope.user.id do %>
            <button
              class="btn btn-ghost"
              popovertarget={"ledger-dropdown-#{@ledger.id}"}
              style={"anchor-name:--anchor-#{@ledger.id}"}
            >
              <.icon name="hero-ellipsis-vertical" class="size-6" />
            </button>
            <ul
              class="dropdown menu w-52 rounded-box bg-base-100 shadow-sm"
              popover
              id={"ledger-dropdown-#{@ledger.id}"}
              style={"position-anchor:--anchor-#{@ledger.id}"}
            >
              <li
                phx-click="open_edit_modal"
                phx-value-id={@ledger.id}
                class="flex items-center flex-row justify-start gap-2 text-blue-600 hover:text-blue-800 hover:cursor-pointer "
              >
                <.link class="hero-pencil"></.link>
                <p>Editar</p>
              </li>
              <li
                phx-click="open_delete_modal"
                phx-value-id={@ledger.id}
                class="flex items-center flex-row justify-start gap-2 text-red-600 hover:text-red-800 hover:cursor-pointer "
              >
                <.link class="hero-trash"></.link>
                <p>Apagar</p>
              </li>
            </ul>
          <% end %>
        </h2>
        <p>
          {@ledger.description}
        </p>
        <div class="card-actions justify-end">
          <button
            class="btn btn-primary"
            phx-click="view_ledger"
            phx-value-ledger-id={@ledger.id}
            phx-target={@myself}
          >
            Visualizar
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("view_ledger", %{"ledger-id" => ledger_id}, socket) do
    {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/ledgers/#{ledger_id}/home")}
  end

  @impl true
  def handle_event("toggle_menu", _params, socket) do
    current_state = socket.assigns.show_menu
    {:noreply, assign(socket, show_menu: !current_state)}
  end
end
