defmodule PersonalFinanceWeb.ProfileLive.Form do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Profile

  @impl true
  def mount(%{"id" => budget_id, "profile_id" => profile_id}, _session, socket) do
    current_budget = Finance.get_budget_by_id(budget_id)

    profile =
      if profile_id do
        Finance.get_profile_by_id(profile_id, budget_id)
      end

    changeset =
      if profile do
        Profile.changeset(profile, %{})
      else
        Profile.changeset(%Profile{}, %{})
      end

    is_edit = profile_id != nil

    socket =
      assign(socket,
        changeset: changeset,
        budget_id: budget_id,
        current_budget: current_budget,
        is_edit: is_edit
      )

    {:ok, socket}
  end

  @impl true
  def mount(%{"id" => budget_id}, _session, socket) do
    current_budget = Finance.get_budget_by_id(budget_id)

    changeset =
      Profile.changeset(%Profile{}, %{})

    socket =
      assign(socket,
        changeset: changeset,
        budget_id: budget_id,
        current_budget: current_budget,
        is_edit: false
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      show_sidebar={true}
      budget_id={@budget_id}
    >
      <.header class="text-center">
        Novo Perfil
        <:subtitle>Crie um novo perfil para seu orçamento</:subtitle>
      </.header>

      <.form
        :let={f}
        for={@changeset}
        id="profile_form"
        phx-submit={if @is_edit, do: "update_profile", else: "create_profile"}
      >
        <.input field={f[:name]} type="text" label="Nome" />
        <.input field={f[:description]} type="text" label="Descrição" />
        <.button variant="primary" phx-disable-with="Saving...">
          {if @is_edit, do: "Atualizar Perfil", else: "Criar Perfil"}
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("create_profile", %{"profile" => profile_params}, socket) do
    budget_id = socket.assigns.budget_id

    case Finance.create_profile(profile_params, budget_id) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile created successfully.")
         |> redirect(to: ~p"/budgets/#{budget_id}/profiles")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("update_profile", %{"profile" => profile_params}, socket) do
    budget_id = socket.assigns.budget_id
    profile_id = socket.assigns.changeset.data.id

    case Finance.update_profile_by_id(profile_id, profile_params, budget_id) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully.")
         |> redirect(to: ~p"/budgets/#{budget_id}/profiles")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
