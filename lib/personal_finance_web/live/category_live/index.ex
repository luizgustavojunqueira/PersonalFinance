defmodule PersonalFinanceWeb.CategoryLive.Index do
  alias PersonalFinance.Finance.Budget
  alias PersonalFinance.Finance.Category
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope

    budget = Finance.get_budget!(current_scope, params["id"])

    socket =
      socket
      |> assign(budget: budget)
      |> stream(:category_collection, Finance.list_categories(current_scope, budget))

    {:ok, socket |> apply_action(socket.assigns.live_action, params, budget)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> apply_action(socket.assigns.live_action, params, socket.assigns.budget)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params, budget) do
    assign(socket,
      page_title: "Categorias - #{budget.name}",
      budget: budget,
      show_form_modal: false,
      category: nil
    )
  end

  defp apply_action(socket, :new, _params, %Budget{} = budget) do
    category = %Category{budget_id: budget.id}

    assign(socket,
      page_title: "Categorias - #{budget.name}",
      budget: budget,
      show_form_modal: true,
      category: category,
      form_action: :new
    )
  end

  defp apply_action(socket, :edit, %{"category_id" => category_id}, %Budget{} = budget) do
    category = Finance.get_category!(socket.assigns.current_scope, category_id, budget)

    assign(socket,
      page_title: "Categorias - #{budget.name}",
      budget: budget,
      show_form_modal: true,
      category: category,
      form_action: :edit
    )
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    category = Finance.get_category!(current_scope, id, socket.assigns.budget)

    case Finance.delete_category(current_scope, category) do
      {:ok, deleted} ->
        {:noreply,
         socket
         |> put_flash(:info, "Categoria removida com sucesso")
         |> stream_delete(:category_collection, deleted)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao remover categoria.")}
    end
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply,
     socket
     |> assign(show_form_modal: false, category: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets/#{socket.assigns.budget.id}/categories")}
  end

  @impl true
  def handle_info({:category_saved, category}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Categoria salva com sucesso.")
     |> stream_insert(:category_collection, category)
     |> assign(show_form_modal: false, category: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets/#{socket.assigns.budget.id}/categories")}
  end
end
