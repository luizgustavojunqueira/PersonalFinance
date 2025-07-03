defmodule PersonalFinanceWeb.ProfileLive.FormModal do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Profile

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       form:
         to_form(
           Finance.change_profile(
             assigns.current_scope,
             assigns.profile || %Profile{budget_id: assigns.budget.id},
             assigns.budget
           )
         )
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex flex-row justify-between mb-5 items-center">
        <h2 class="text-2xl font-semibold mb-4 ">
          <%= if @action == :edit do %>
            Editar Perfil
          <% else %>
            Novo Perfil
          <% end %>
        </h2>

        <.link class="text-red-600 hover:text-red-800 hero-x-mark" phx-click="close_form"></.link>
      </div>

      <.form
        for={@form}
        id="profile-form"
        phx-change="validate"
        phx-submit="save"
        phx-target={@myself}
        class="flex flex-col gap-4"
      >
        <.input field={@form[:name]} type="text" label="Nome" />
        <.input field={@form[:description]} type="text" label="Descrição" />
        <.button variant="primary" phx-disable-with="Salvando">
          <.icon name="hero-check" /> Salvar Perfil
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("save", %{"profile" => profile_params}, socket) do
    save_profile(socket, socket.assigns.action, profile_params)
  end

  @impl true
  def handle_event("validate", %{"profile" => profile_params}, socket) do
    changeset =
      Finance.change_profile(
        socket.assigns.current_scope,
        socket.assigns.profile,
        socket.assigns.budget,
        profile_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  defp save_profile(socket, :edit, profile_params) do
    case Finance.update_profile(
           socket.assigns.current_scope,
           socket.assigns.profile,
           profile_params
         ) do
      {:ok, profile} ->
        send(socket.assigns.parent_pid, {:profile_saved, profile})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_profile(socket, :new, profile_params) do
    case Finance.create_profile(
           socket.assigns.current_scope,
           profile_params,
           socket.assigns.budget
         ) do
      {:ok, profile} ->
        send(socket.assigns.parent_pid, {:profile_saved, profile})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Profile Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
