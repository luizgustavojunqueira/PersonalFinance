defmodule PersonalFinanceWeb.SettingsLive.InviteForm do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Finance

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(selected_user_id: nil)
     |> assign(invite_form: to_form(%{"user_id" => nil}, as: :ledger_invite))
     |> assign(
       users:
         Enum.map(
           Finance.list_available_ledger_users(assigns.current_scope, assigns.ledger),
           fn user -> {user.name, user.id} end
         )
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="rounded-lg p-6 bg-base-100/50 w-full shadow-lg">
      <h2 class="text-2xl font-bold mb-4">
        Convidar
      </h2>
      <.form
        for={@invite_form}
        id="invite-form"
        phx-submit="add_user"
        phx-change="validate_invite"
        phx-target={@myself}
      >
        <div class="flex flex-col gap-2">
          <.input
            field={@invite_form[:user_id]}
            type="select"
            label="Usuário"
            options={@users}
            prompt="Selecione um usuário"
          />
          <.button
            variant="primary"
            phx-disable-with="Salvando"
            disabled={@selected_user_id in [nil, ""]}
          >
            Adicionar Convidado
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate_invite", %{"ledger_invite" => %{"user_id" => id}}, socket) do
    {:noreply, assign(socket, selected_user_id: id)}
  end

  @impl true
  def handle_event("add_user", %{"ledger_invite" => %{"user_id" => user_id}}, socket) do
    ledger = socket.assigns.ledger

    case Finance.add_ledger_user(socket.assigns.current_scope, ledger, user_id) do
      {:ok, user} ->
        send(socket.assigns.parent_pid, {:user_added, user})

        {:noreply,
         socket
         |> assign(selected_user_id: nil)
         |> assign(
           users:
             Enum.map(
               Finance.list_available_ledger_users(socket.assigns.current_scope, ledger),
               fn user -> {user.name, user.id} end
             )
         )
         |> assign(invite_form: to_form(%{"user_id" => nil}, as: :ledger_invite))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, invite_form: to_form(changeset))}

      {:error, message} ->
        send(
          socket.assigns.parent_pid,
          {:error, message}
        )

        {:noreply,
         socket
         |> assign(invite_form: to_form(%{"user_id" => nil}, as: :ledger_invite))}
    end
  end
end
