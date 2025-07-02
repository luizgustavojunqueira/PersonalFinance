defmodule PersonalFinanceWeb.ProfileLive.Form do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Profile

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      show_sidebar={true}
      budget_id={@budget.id}
    >
      <.header class="text-center">
        Novo Perfil
        <:subtitle>Crie um novo perfil para seu orçamento</:subtitle>
      </.header>

      <.form for={@form} id="profile_form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Nome" />
        <.input field={@form[:description]} type="text" label="Descrição" />
        <.button variant="primary" phx-disable-with="Saving...">
          <.icon name="hero-check" /> Salvar Perfil
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => budget_id, "profile_id" => profile_id}) do
    case Finance.get_budget!(socket.assigns.current_scope, budget_id) do
      current_budget ->
        case Finance.get_profile!(socket.assigns.current_scope, budget_id, profile_id) do
          profile ->
            assign(socket,
              page_title: "Edit Profile",
              budget: current_budget,
              profile: profile,
              form:
                to_form(
                  Finance.change_profile(socket.assigns.current_scope, profile, current_budget)
                )
            )
        end
    end
  end

  defp apply_action(socket, :new, %{"id" => budget_id}) do
    case Finance.get_budget!(socket.assigns.current_scope, budget_id) do
      current_budget ->
        profile = %Profile{budget_id: current_budget.id}

        assign(socket,
          page_title: "Novo Perfil",
          budget: current_budget,
          profile: profile,
          form:
            to_form(Finance.change_profile(socket.assigns.current_scope, profile, current_budget))
        )
    end
  end

  @impl true
  def handle_event("save", %{"profile" => profile_params}, socket) do
    save_profile(socket, socket.assigns.live_action, profile_params)
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
        {:noreply,
         socket
         |> put_flash(:info, "Perfil atualizado com sucesso.")
         |> redirect(to: ~p"/budgets/#{profile.budget_id}/profiles")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_profile(socket, :new, profile_params) do
    budget_id = socket.assigns.budget.id

    case Finance.create_profile(
           socket.assigns.current_scope,
           profile_params,
           budget_id
         ) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Perfil criado com sucesso.")
         |> redirect(to: ~p"/budgets/#{profile.budget_id}/profiles")}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Profile Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
