defmodule PersonalFinanceWeb.BudgetsLive.BudgetCardItem do
  use PersonalFinanceWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, show_menu: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="flex flex-col rounded-xl light min-h-40 min-w-85 max-w-85 items-center p-0 relative bg-light-green/15 shadow-2xl"
      id={@id}
    >
      <div class="flex justify-between w-full h-1/4 rounded-t-xl text-center p-2 px-4 bg-medium-green/20">
        <span class="font-bold">{@budget.name}</span>
        <%= if @budget.owner.id == @current_scope.user.id do %>
          <.link class="hero-ellipsis-vertical" phx-click="toggle_menu" phx-target={@myself}></.link>
        <% end %>
      </div>

      <span class="w-full p-2 px-6 text-center h-2/4 flex items-center justify-center">
        {@budget.description}
      </span>
      <.button
        variant="custom"
        class="bg-accent/90 hover:bg-accent text-white p-2 rounded-b-xl w-full primary-button min-h-10 h-1/4"
        phx-click="view_budget"
        phx-value-budget-id={@budget.id}
        phx-target={@myself}
      >
        Visualizar
      </.button>
      <%= if @show_menu do %>
        <div class="absolute right-5 top-5 p-2 flex flex-col gap-4 rounded-xl shadow-lg bg-white ">
          <span
            phx-click="edit_budget"
            phx-value-id={@budget.id}
            phx-target={@myself}
            class="flex items-center flex-row justify-start gap-2 text-blue-600 hover:text-blue-800 hover:cursor-pointer "
          >
            <.link class="hero-pencil"></.link>
            <p>Editar</p>
          </span>

          <span
            phx-click="delete_budget"
            phx-value-id={@budget.id}
            phx-target={@myself}
            class="flex items-center flex-row justify-start gap-2 text-red-600 hover:text-red-800 hover:cursor-pointer "
          >
            <.link class="hero-trash"></.link>
            <p>Apagar</p>
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("view_budget", %{"budget-id" => budget_id}, socket) do
    {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/budgets/#{budget_id}/home")}
  end

  @impl true
  def handle_event("toggle_menu", _params, socket) do
    current_state = socket.assigns.show_menu
    {:noreply, assign(socket, show_menu: !current_state)}
  end

  @impl true
  def handle_event("edit_budget", %{"id" => id}, socket) do
    {:noreply, Phoenix.LiveView.push_patch(socket, to: ~p"/budgets/#{id}/edit")}
  end

  @impl true
  def handle_event("delete_budget", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    budget = PersonalFinance.Finance.get_budget(current_scope, id)

    case PersonalFinance.Finance.delete_budget(current_scope, budget) do
      {:ok, deleted} ->
        send(socket.assigns.parent_pid, {:deleted, deleted})
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, assign(socket, show_menu: false)}
    end
  end
end
