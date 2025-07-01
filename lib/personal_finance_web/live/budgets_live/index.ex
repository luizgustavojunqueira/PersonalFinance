defmodule PersonalFinanceWeb.BudgetsLive.Index do
  alias PersonalFinance.Finance.Budget
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    user_budgets = Finance.list_budgets_for_user(current_user)

    changeset = Budget.changeset(%Budget{}, %{})

    socket =
      socket
      |> assign(show_form: false, selected_budget: nil, budget_id: nil, changeset: changeset)
      |> stream(:budgets, user_budgets, id: & &1.id)

    {:ok, socket}
  end

  @impl true
  def handle_event("create_budget", %{"budget" => budget_params}, socket) do
    params_with_user =
      Map.put(budget_params, "owner_id", socket.assigns.current_scope.user.id)

    case Finance.create_budget(params_with_user) do
      {:ok, added} ->
        new_changeset = Budget.changeset(%Budget{}, %{})

        {:noreply,
         socket
         |> stream_insert(:budgets, added)
         |> assign(
           changeset: new_changeset,
           selected_budget: nil,
           show_form: false
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("validate_budget", %{"budget" => params}, socket) do
    changeset =
      Budget.changeset(
        socket.assigns.selected_budget || %Budget{},
        params
      )

    {:noreply,
     assign(socket,
       action: :validate,
       changeset: changeset
     )}
  end

  @impl true
  def handle_event("open_form", _params, socket) do
    changeset = Budget.changeset(%Budget{}, %{})

    {:noreply,
     assign(socket,
       show_form: true,
       selected_budget: nil,
       changeset: changeset
     )}
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, selected_budget: nil)}
  end

  @impl true
  def handle_event("update_budget", %{"budget" => budget_params}, socket) do
    b = socket.assigns.selected_budget

    case Finance.update_budget(b, budget_params) do
      {:ok, updated} ->
        new_changeset = Budget.changeset(%Budget{}, %{})

        {:noreply,
         socket
         |> stream_insert(:budgets, updated)
         |> assign(
           changeset: new_changeset,
           selected_budget: nil,
           show_form: false
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_info({:edit_budget, id}, socket) do
    budget = Finance.get_budget_by_id(String.to_integer(id))
    changeset = Budget.changeset(budget, %{})

    {:noreply,
     assign(socket,
       selected_budget: budget,
       show_form: true,
       changeset: changeset
     )}
  end

  @impl true
  def handle_info({:delete_budget, id}, socket) do
    budget = Finance.get_budget_by_id(String.to_integer(id))

    case Finance.delete_budget(budget) do
      {:ok, deleted} ->
        {:noreply, stream_delete(socket, :budgets, deleted)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end
end
