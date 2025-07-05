defmodule PersonalFinanceWeb.HomeLive.Index do
  alias PersonalFinance.Finance.BudgetInvite
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope
    budget = Finance.get_budget(current_scope, params["id"])

    if budget == nil do
      {:ok,
       socket
       |> put_flash(:error, "Orçamento não encontrado.")
       |> push_navigate(to: ~p"/budgets")}
    else
      transactions = Finance.list_transactions(current_scope, budget)

      categories = Finance.list_categories(current_scope, budget)

      labels =
        Enum.map(categories, fn category ->
          category.name
        end)

      values =
        Enum.map(categories, fn category ->
          Finance.get_total_value_by_category(category.id, transactions)
        end)

      socket =
        socket
        |> assign(
          current_user: current_scope.user,
          budget: budget,
          page_title: "Home #{budget.name}",
          show_welcome_message: true,
          show_form_modal: socket.assigns.live_action == :new,
          form_action: socket.assigns.live_action,
          labels: labels,
          values: values,
          form: to_form(BudgetInvite.changeset(%BudgetInvite{}, %{})),
          invite_url: nil
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply,
     socket
     |> assign(show_form_modal: false, form_action: nil, invite_url: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets/#{socket.assigns.budget.id}/home")}
  end

  @impl true
  def handle_event("send_invite", %{"budget_invite" => %{"email" => email}}, socket) do
    budget = socket.assigns.budget

    case Finance.create_budget_invite(socket.assigns.current_scope, budget, email) do
      {:ok, %BudgetInvite{} = invite} ->
        invite_url = "http://localhost:4000/join/#{invite.token}"

        {:noreply,
         socket
         |> put_flash(:info, "Convite enviado para #{email}!")
         |> assign(
           invite_url: invite_url,
           invite_form: to_form(BudgetInvite.changeset(invite, %{}))
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, invite_form: to_form(changeset))}
    end
  end
end
