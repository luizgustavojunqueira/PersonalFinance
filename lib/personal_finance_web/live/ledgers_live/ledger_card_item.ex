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
          <div class="dropdown">
            <div
              tabindex="0"
              role="button"
              class="btn m-1 p-0 bg-transparent hover:bg-transparent border-0 shadow-none"
            >
              <.icon name="hero-ellipsis-vertical" class="size-6" />
            </div>
            <ul
              tabindex="0"
              class="dropdown-content menu bg-base-100 rounded-box z-1 w-52 p-2 shadow-sm"
            >
              <li
                phx-click="edit_ledger"
                phx-value-id={@ledger.id}
                phx-target={@myself}
                class="flex items-center flex-row justify-start gap-2 text-blue-600 hover:text-blue-800 hover:cursor-pointer "
              >
                <.link class="hero-pencil"></.link>
                <p>Editar</p>
              </li>
              <li
                phx-click="delete_ledger"
                phx-value-id={@ledger.id}
                phx-target={@myself}
                class="flex items-center flex-row justify-start gap-2 text-red-600 hover:text-red-800 hover:cursor-pointer "
              >
                <.link class="hero-trash"></.link>
                <p>Apagar</p>
              </li>
            </ul>
          </div>
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
    <%!-- <div --%>
    <%!--   class="flex flex-col rounded-xl light min-h-40 min-w-85 max-w-85 items-center p-0 relative bg-light-green/15 text-dark-green dark:text-offwhite shadow-2xl" --%>
    <%!-- > --%>
    <%!--   <div class="flex justify-between w-full h-1/4 rounded-t-xl text-center p-2 px-4 bg-medium-green/20"> --%>
    <%!--     <span class="font-bold">{@ledger.name}</span> --%>
    <%!--     <%= if @ledger.owner.id == @current_scope.user.id do %> --%>
    <%!--       <.link class="hero-ellipsis-vertical" phx-click="toggle_menu" phx-target={@myself}> --%>
    <%!--       </.link> --%>
    <%!--     <% end %> --%>
    <%!--   </div> --%>
    <%!----%>
    <%!--   <span class="w-full p-2 px-6 text-center h-2/4 flex items-center justify-center"> --%>
    <%!--     {@ledger.description} --%>
    <%!--   </span> --%>
    <%!--   <.button --%>
    <%!--     variant="custom" --%>
    <%!--     class="bg-accent/90 hover:bg-accent text-white p-2 rounded-b-xl w-full primary-button min-h-10 h-1/4" --%>
    <%!--     phx-click="view_ledger" --%>
    <%!--     phx-value-ledger-id={@ledger.id} --%>
    <%!--     phx-target={@myself} --%>
    <%!--   > --%>
    <%!--     Visualizar --%>
    <%!--   </.button> --%>
    <%!--   <%= if @show_menu do %> --%>
    <%!--     <div class="absolute right-5 top-5 p-2 flex flex-col gap-4 rounded-xl shadow-lg bg-white "> --%>
    <%!--       <span --%>
    <%!--         phx-click="edit_ledger" --%>
    <%!--         phx-value-id={@ledger.id} --%>
    <%!--         phx-target={@myself} --%>
    <%!--         class="flex items-center flex-row justify-start gap-2 text-blue-600 hover:text-blue-800 hover:cursor-pointer " --%>
    <%!--       > --%>
    <%!--         <.link class="hero-pencil"></.link> --%>
    <%!--         <p>Editar</p> --%>
    <%!--       </span> --%>
    <%!----%>
    <%!--       <span --%>
    <%!--         phx-click="delete_ledger" --%>
    <%!--         phx-value-id={@ledger.id} --%>
    <%!--         phx-target={@myself} --%>
    <%!--         class="flex items-center flex-row justify-start gap-2 text-red-600 hover:text-red-800 hover:cursor-pointer " --%>
    <%!--       > --%>
    <%!--         <.link class="hero-trash"></.link> --%>
    <%!--         <p>Apagar</p> --%>
    <%!--       </span> --%>
    <%!--     </div> --%>
    <%!--   <% end %> --%>
    <%!-- </div> --%>
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

  @impl true
  def handle_event("edit_ledger", %{"id" => id}, socket) do
    {:noreply, Phoenix.LiveView.push_patch(socket, to: ~p"/ledgers/#{id}/edit")}
  end

  @impl true
  def handle_event("delete_ledger", %{"id" => id}, socket) do
    {:noreply, Phoenix.LiveView.push_patch(socket, to: ~p"/ledgers/#{id}/delete")}
  end
end
