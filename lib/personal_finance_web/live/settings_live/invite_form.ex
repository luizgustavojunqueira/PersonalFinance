defmodule PersonalFinanceWeb.SettingsLive.InviteForm do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.BudgetInvite

  @impl true
  def mount(socket) do
    invite_form = to_form(BudgetInvite.changeset(%BudgetInvite{}, %{}))

    {:ok,
     socket
     |> assign(
       invite_form: invite_form,
       invite_url: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="rounded-lg shadow-md p-6 bg-light-green/50 w-full shadow-lg dark:bg-medium-green/25 text-dark-green dark:text-offwhite">
      <h2 class="text-2xl font-bold mb-4">
        Convidar
      </h2>
      <.form
        title="Convidado"
        for={@invite_form}
        id="invite-form"
        phx-submit="send_invite"
        phx-target={@myself}
      >
        <.input field={@invite_form[:email]} type="email" label="Email" />

        <%= if @invite_url do %>
          <div class="alert alert-info mb-4">
            <p>
              Convite gerado com sucesso! Compartilhe o link abaixo com a pessoa convidada:
              <a href={@invite_url} class="text-blue-600 hover:text-blue-800" target="_blank">
                {@invite_url}
              </a>
            </p>
          </div>
        <% end %>

        <.button variant="primary" phx-disable-with="Salvando">
          <.icon name="hero-check" /> Gerar convite
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("send_invite", %{"budget_invite" => %{"email" => email}}, socket) do
    budget = socket.assigns.budget

    case Finance.create_budget_invite(socket.assigns.current_scope, budget, email) do
      {:ok, %BudgetInvite{} = invite} ->
        invite_url = "http://localhost:4000/join/#{invite.token}"

        send(socket.assigns.parent_pid, {:invite_sent, invite})

        {:noreply,
         socket
         |> put_flash(:info, "Convite enviado para #{email}!")
         |> assign(
           invite_url: invite_url,
           invite_form: to_form(BudgetInvite.changeset(invite, %{}))
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, invite_form: to_form(changeset))}
    end
  end
end
