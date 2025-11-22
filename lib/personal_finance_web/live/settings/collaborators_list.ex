defmodule PersonalFinanceWeb.SettingsLive.CollaboratorsList do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Finance

  @impl true
  def update(assigns, socket) do
    ledger = Map.get(assigns, :ledger) || socket.assigns.ledger
    current_scope = Map.get(assigns, :current_scope) || socket.assigns.current_scope

    ledger_users = Finance.list_ledger_users(current_scope, ledger)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       ledger_users: ledger_users,
       page_title: "Colaboradores"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="rounded-lg p-6 w-full shadow-lg bg-base-100/50">
      <h2 class="text-2xl font-bold mb-4">
        Colaboradores
      </h2>

      <%= if @ledger_users == [] do %>
        <p class="text-gray-500">Nenhum colaborador adicionado.</p>
      <% else %>
        <.table
          id="ledger_users_table"
          rows={@ledger_users}
          col_widths={["30%", "20%", "5%"]}
        >
          <:col :let={user} label="Colaborador">
            {user.name} ({user.email})
          </:col>
          <:col :let={user} label="Tipo">
            <span class="light">
              <%= if @ledger.owner_id == user.id do %>
                Dono
              <% else %>
                Colaborador
              <% end %>
            </span>
          </:col>
          <:action :let={user}>
            <%= if @ledger.owner_id != user.id && @ledger.owner_id == @current_scope.user.id do %>
              <.link
                class="text-red-600 hover:text-red-800"
                phx-click="remove_user"
                phx-value-id={user.id}
                phx-target={@myself}
              >
                <.icon name="hero-trash" class="text-red-500 hover:text-red-800" />
              </.link>
            <% end %>
          </:action>
        </.table>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("remove_user", %{"id" => user_id}, socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope

    case Finance.remove_ledger_user(current_scope, ledger, user_id) do
      {:ok, _} ->
        send(socket.assigns.parent_pid, {:user_removed, user_id})

        {:noreply,
         assign(
           socket,
           :ledger_users,
           Finance.list_ledger_users(current_scope, ledger)
         )}

      {:error, reason} ->
        {:noreply, assign(socket, :error_message, reason)}
    end
  end
end
