defmodule PersonalFinanceWeb.SettingsLive.CollaboratorsList do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Finance

  @impl true
  def update(assigns, socket) do
    ledger = Map.get(assigns, :ledger) || socket.assigns.ledger
    current_scope = Map.get(assigns, :current_scope) || socket.assigns.current_scope

    ledger_users = Finance.list_ledger_users(current_scope, ledger)
    ledger_invites = Finance.list_ledger_invites(current_scope, ledger, :pending)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       ledger_users: ledger_users,
       ledger_invites: ledger_invites,
       page_title: "Colaboradores"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="rounded-lg shadow-md p-6 w-full shadow-lg bg-base-100/50">
      <h2 class="text-2xl font-bold mb-4">
        Colaboradores
      </h2>

      <%= if @ledger_users == [] do %>
        <p class="text-gray-500">Nenhum colaborador adicionado.</p>
      <% else %>
        <.table id="ledger_users_table" rows={@ledger_users}>
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
          <:col :let={user} label="Ações">
            <%= if @ledger.owner_id != user.id && @ledger.owner_id == @current_scope.user.id do %>
              <.link
                class="text-red-600 hover:text-red-800"
                phx-click="remove_user"
                phx-value-id={user.id}
                phx-target={@myself}
              >
                Remover
              </.link>
            <% end %>
          </:col>
        </.table>
      <% end %>

      <h2 class="text-2xl font-bold mt-8 mb-4">
        Convites Pendentes
      </h2>

      <%= if @ledger_invites == [] do %>
        <p>Nenhum convite pendente.</p>
      <% else %>
        <.table id="ledger_invites_table" rows={@ledger_invites}>
          <:col :let={invite} label="Email">
            {invite.email}
          </:col>
          <:col :let={invite} label="Data de Criação">
            {invite.inserted_at}
          </:col>
          <:col :let={invite} label="Data de Expiração">
            {invite.expires_at}
          </:col>
          <:col :let={invite} label="Status">
            <span class="text-green
            -600">
              <%= if invite.status == :pending do %>
                Pendente
              <% else %>
                Expirado
              <% end %>
            </span>
          </:col>

          <:col :let={invite} label="Ações">
            <.link
              class="text-blue-600 hover:text-blue-800 ml-2"
              phx-hook="Copy"
              data-to={"#invite-link#{invite.id}"}
              title="Copiar Link"
              id={"copy-invite-link-#{invite.id}"}
            >
              <.icon name="hero-clipboard" />
            </.link>
            <span id={"invite-link#{invite.id}"} class="hidden">
              http://localhost:4000/join/{invite.token}
            </span>
            <.link
              class="text-red-600 hover:text-red-800 hero-trash"
              phx-click="revoke_invite"
              phx-value-id={invite.id}
              phx-target={@myself}
            >
            </.link>
          </:col>
        </.table>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("revoke_invite", %{"id" => id}, socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope

    case Finance.revoke_ledger_invite(current_scope, ledger, id) do
      {:ok, _invite} ->
        {:noreply,
         assign(
           socket,
           :ledger_invites,
           Finance.list_ledger_invites(current_scope, ledger, :pending)
         )}

      {:error, reason} ->
        {:noreply, assign(socket, :error_message, reason)}
    end
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
