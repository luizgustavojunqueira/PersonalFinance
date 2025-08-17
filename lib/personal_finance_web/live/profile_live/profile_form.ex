defmodule PersonalFinanceWeb.ProfileLive.ProfileForm do
  alias PersonalFinance.Finance.Profile
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_component

  @impl true
  def update(assigns, socket) do
    ledger = assigns.ledger
    current_scope = assigns.current_scope

    profile =
      assigns.profile || %Profile{ledger_id: ledger.id}

    changeset =
      Finance.change_profile(
        current_scope,
        profile,
        ledger,
        %{}
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(form: to_form(changeset, as: :profile))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal
        show={@show}
        id={@id}
        on_close={JS.push("close_modal")}
        class="mt-2"
      >
        <:title>{if @action == :edit, do: "Editar Perfil", else: "Novo Perfil"}</:title>
        <.form
          for={@form}
          id="profile-form"
          phx-submit="save"
          phx-change="validate"
          phx-target={@myself}
        >
          <.input field={@form[:name]} type="text" label="Nome" />
          <.input field={@form[:description]} type="text" label="Descrição" />
          <.input field={@form[:color]} type="color" label="Cor" />
          <div class="flex justify-center gap-2 mt-4">
            <.button
              variant="custom"
              class="btn btn-primary w-full"
              phx-disable-with="Salvando..."
            >
              Salvar
            </.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"profile" => profile_params}, socket) do
    changeset =
      Finance.change_profile(
        socket.assigns.current_scope,
        socket.assigns.profile || %Profile{ledger_id: socket.assigns.ledger.id},
        socket.assigns.ledger,
        profile_params
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate)
     )}
  end

  @impl true
  def handle_event("save", %{"profile" => profile_params}, socket) do
    case save_profile(socket, socket.assigns.action, profile_params) do
      {:ok, profile} ->
        send(self(), {:saved, profile})
        {:noreply, assign(socket, show: false)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_profile(socket, :new, profile_params) do
    Finance.create_profile(
      socket.assigns.current_scope,
      profile_params,
      socket.assigns.ledger
    )
  end

  defp save_profile(socket, :edit, profile_params) do
    Finance.update_profile(
      socket.assigns.current_scope,
      socket.assigns.profile,
      profile_params
    )
  end
end
