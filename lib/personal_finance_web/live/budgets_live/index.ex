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
      budget: budget,
      form:
        to_form(
          Finance.change_budget(
            socket.assigns.current_scope,
            budget
          )
        )
    )
  end

  defp apply_action(socket, :edit, %{"id" => budget_id}) do
    budget = Finance.get_budget(socket.assigns.current_scope, budget_id)

    if budget == nil do
      socket
      |> put_flash(:error, "Orçamento não encontrado.")
      |> push_navigate(to: ~p"/budgets")
    else
      assign(socket,
        page_title: "Orçamentos",
        show_form_modal: true,
        form_action: :edit,
        budget: budget,
        form:
          to_form(
            Finance.change_budget(
              socket.assigns.current_scope,
              budget
            )
          )
      )
    end
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
  def handle_event("save", %{"budget" => budget_params}, socket) do
    save_budget(socket, socket.assigns.form_action, budget_params)
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
        send(self(), {:budget_saved, budget})

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

        send(self(), {:budget_saved, budget})
        {:noreply, socket}

      {:error, changeset} ->
        IO.inspect(changeset, label: "Budget Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_info({:budget_deleted, budget}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Orçamento apagado com sucesso.")
     |> stream_delete(:budget_collection, budget)}
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
end
