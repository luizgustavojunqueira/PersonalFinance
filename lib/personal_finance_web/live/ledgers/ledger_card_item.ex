defmodule PersonalFinanceWeb.LedgersLive.LedgerCardItem do
  use PersonalFinanceWeb, :live_component

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
            <div class="dropdown dropdown-end">
              <label tabindex="0" class="btn btn-ghost btn-square">
                <.icon name="hero-ellipsis-vertical" class="size-6" />
              </label>
              <ul tabindex="0" class="dropdown-content menu w-52 rounded-box bg-base-100 shadow-lg p-2 z-10">
                <li>
                  <.link patch={~p"/ledgers/#{@ledger.id}/edit"} class="flex items-center gap-2 text-blue-600 hover:text-blue-800">
                    <.icon name="hero-pencil" />
                    <span>Editar</span>
                  </.link>
                </li>
                <li>
                  <.link patch={~p"/ledgers/#{@ledger.id}/delete"} class="flex items-center gap-2 text-red-600 hover:text-red-800">
                    <.icon name="hero-trash" />
                    <span>Apagar</span>
                  </.link>
                </li>
              </ul>
            </div>
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
end
