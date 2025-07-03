defmodule PersonalFinanceWeb.TransactionLive.Index do
  alias PersonalFinance.Finance.{Transaction}
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope

    budget = Finance.get_budget!(current_scope, params["id"])

    categories = Finance.list_categories(current_scope, budget)

    investment_category =
      Finance.get_category_by_name("Investimento", socket.assigns.current_scope, budget)

    investment_types = Finance.list_investment_types()

    profiles = Finance.list_profiles(socket.assigns.current_scope, budget)

    socket =
      socket
      |> assign(
        categories: Enum.map(categories, fn category -> {category.name, category.id} end),
        investment_category_id: if(investment_category, do: investment_category.id, else: nil),
        investment_types: Enum.map(investment_types, fn type -> {type.name, type.id} end),
        profiles: Enum.map(profiles, fn profile -> {profile.name, profile.id} end),
        selected_category_id: nil
      )
      |> stream(:transaction_collection, Finance.list_transactions(current_scope, budget))

    {:ok, socket |> apply_action(socket.assigns.live_action, params, budget)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> apply_action(socket.assigns.live_action, params, socket.assigns.budget)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params, budget) do
    assign(socket,
      page_title: "Transações - #{budget.name}",
      budget: budget,
      show_form_modal: false,
      transaction: nil,
      selected_category_id: nil,
      investment_category_id:
        Finance.get_category_by_name("Investimento", socket.assigns.current_scope, budget).id
    )
  end

  defp apply_action(socket, :new, _params, budget) do
    transaction = %Transaction{budget_id: budget.id}

    assign(socket,
      page_title: "Nova Transação",
      budget: budget,
      transaction: transaction,
      form_action: :new,
      show_form_modal: true,
      form:
        to_form(
          Finance.change_transaction(
            socket.assigns.current_scope,
            transaction,
            budget
          )
        )
    )
  end

  defp apply_action(socket, :edit, %{"transaction_id" => transaction_id}, budget) do
    transaction =
      Finance.get_transaction!(socket.assigns.current_scope, transaction_id, budget)

    selected_category_id =
      transaction.category_id ||
        socket.assigns.selected_category_id

    assign(socket,
      page_title: "Editar Transação",
      budget: budget,
      transaction: transaction,
      form_action: :edit,
      show_form_modal: true,
      selected_category_id: selected_category_id,
      form:
        to_form(
          Finance.change_transaction(
            socket.assigns.current_scope,
            transaction,
            budget
          )
        )
    )
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    transaction =
      Finance.get_transaction!(current_scope, id, socket.assigns.budget)

    case Finance.delete_transaction(current_scope, transaction) do
      {:ok, deleted} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transação removida com sucesso")
         |> stream_delete(:transaction_collection, deleted)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao remover transação.")}
    end
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply,
     socket
     |> assign(show_form_modal: false, transaction: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets/#{socket.assigns.budget.id}/transactions")}
  end

  @impl true
  def handle_info({:transaction_saved, transaction}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Transação salva com sucesso.")
     |> stream_insert(:transaction_collection, transaction)
     |> assign(show_form_modal: false, transaction: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets/#{socket.assigns.budget.id}/transactions")}
  end

  def format_date(nil), do: "Data não disponível"
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")
  def format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  def format_date(_), do: "Data inválida"

  def format_money(nil), do: "R$ 0,00"

  def format_money(value) when is_float(value) or is_integer(value) do
    formatted_value = :erlang.float_to_binary(value, [:compact, decimals: 2])
    "R$ #{formatted_value}"
  end

  def format_amount(nil), do: "0,00"

  def format_amount(value, cripto \\ false) when is_float(value) or is_integer(value) do
    if cripto do
      :erlang.float_to_binary(value, [:compact, decimals: 8])
    else
      :erlang.float_to_binary(value, [:compact, decimals: 2])
    end
  end
end
