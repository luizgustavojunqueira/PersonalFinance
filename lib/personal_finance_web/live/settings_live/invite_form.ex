defmodule PersonalFinanceWeb.SettingsLive.InviteForm do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Accounts
  alias PersonalFinance.Finance

  @impl true
  def update(assigns, socket) do
    invite_form =
      to_form(
        %{
          "user_id" => nil
        },
        as: :ledger_invite
      )

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       invite_form: invite_form,
       users:
         Enum.map(
           Accounts.list_users_except(assigns.current_scope.user.id),
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
        title="Convidado"
        for={@invite_form}
        id="invite-form"
        phx-submit="add_user"
        phx-target={@myself}
      >
        <div class="flex flex-col gap-2">
          <.input field={@invite_form[:user_id]} type="select" label="Usuário" options={@users} />

          <.button variant="primary" phx-disable-with="Salvando">
            Adicionar Convidado
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("add_user", %{"ledger_invite" => %{"user_id" => user_id}}, socket) do
    ledger = socket.assigns.ledger

    case Finance.add_ledger_user(socket.assigns.current_scope, ledger, user_id) do
      {:ok, user} ->
        send(socket.assigns.parent_pid, {:user_added, user})

        {:noreply,
         socket
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
