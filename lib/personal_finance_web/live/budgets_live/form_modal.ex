defmodule PersonalFinanceWeb.BudgetLive.FormModal do
  use PersonalFinanceWeb, :live_component

  require Logger
  alias PersonalFinance.Finance

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       form:
         to_form(
           Finance.change_budget(
             assigns.current_scope,
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
            Editar Orçamento
          <% else %>
            Novo Orçamento
          <% end %>
        </h2>

        <.link class="text-red-600 hover:text-red-800 hero-x-mark" phx-click="close_form"></.link>
      </div>

      <.form
        id="budget-form"
        for={@form}
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
        class="flex flex-col gap-4"
      >
        <.input
          field={@form[:name]}
          id="input-name"
          type="text"
          label="Nome"
          placeholder="Ex: Alimentação"
          required
        />
        <.input
          field={@form[:description]}
          id="input-description"
          type="text"
          label="Descrição"
          placeholder="Ex: Despesas com alimentação"
          required
        />

        <.button variant="primary" phx-disable-with="Salvando">
          <.icon name="hero-check" /> Salvar Orçamento
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("save", %{"budget" => budget_params}, socket) do
    save_budget(socket, socket.assigns.action, budget_params)
  end

  @impl true
  def handle_event("validate", %{"budget" => budget_params}, socket) do
    changeset =
      Finance.change_budget(
        socket.assigns.current_scope,
        socket.assigns.budget,
        budget_params
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate)
     )}
  end

  defp save_budget(socket, :edit, budget_params) do
    case Finance.update_budget(
           socket.assigns.current_scope,
           socket.assigns.budget,
           budget_params
         ) do
      {:ok, budget} ->
        send(socket.assigns.parent_pid, {:budget_saved, budget})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_budget(socket, :new, budget_params) do
    case Finance.create_budget(
           socket.assigns.current_scope,
           budget_params
         ) do
      {:ok, budget} ->
        Finance.create_default_profiles(socket.assigns.current_scope, budget)

        Finance.create_default_categories(socket.assigns.current_scope, budget)

        send(socket.assigns.parent_pid, {:budget_saved, budget})
        {:noreply, socket}

      {:error, changeset} ->
        IO.inspect(changeset, label: "Budget Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
