defmodule PersonalFinanceWeb.BudgetsLive.Index do
  alias PersonalFinance.Finance.Budget
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> stream(:budget_collection, Finance.list_budgets(current_scope))

    {:ok, socket |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket,
      page_title: "Orçamentos",
      show_form_modal: false,
      budget: nil
    )
  end

  defp apply_action(socket, :new, _params) do
    budget = %Budget{owner_id: socket.assigns.current_scope.user.id}

    assign(socket,
      page_title: "Orçamentos",
      show_form_modal: true,
      form_action: :new,
      budget: budget
    )
  end

  defp apply_action(socket, :edit, %{"id" => budget_id}) do
    budget = Finance.get_budget!(socket.assigns.current_scope, budget_id)

    assign(socket,
      page_title: "Orçamentos",
      show_form_modal: true,
      form_action: :edit,
      budget: budget
    )
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply,
     socket
     |> assign(show_form_modal: false, budget: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets")}
  end

  @impl true
  def handle_info({:budget_saved, budget}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Orçamento salvo com sucesso.")
     |> stream_insert(:budget_collection, budget)
     |> assign(show_form_modal: false, category: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets")}
  end

  @impl true
  def handle_info({:budget_deleted, budget}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Orçamento apagado com sucesso.")
     |> stream_delete(:budget_collection, budget)
     |> assign(show_form_modal: false, budget: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets")}
  end
end
