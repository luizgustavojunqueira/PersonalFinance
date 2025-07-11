defmodule PersonalFinanceWeb.TransactionLive.Index do
  alias PersonalFinance.Finance.{Transaction}
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
      Finance.subscribe_finance(:transaction, budget.id)
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
      show_pending_transactions_drawer: false,
      transaction: nil,
      selected_category_id: nil
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
      show_pending_transactions_drawer: false,
      form:
        to_form(
          Finance.change_transaction(
            socket.assigns.current_scope,
            %Transaction{budget_id: budget.id},
            budget
          )
        )
    )
  end

  defp apply_action(socket, :edit, %{"transaction_id" => transaction_id}, budget) do
    transaction =
      Finance.get_transaction(socket.assigns.current_scope, transaction_id, budget)

    if transaction == nil do
      socket
      |> put_flash(:error, "Transação não encontrada.")
      |> push_navigate(to: ~p"/budgets/#{budget.id}/transactions")
    else
      selected_category_id =
        transaction.category_id ||
          socket.assigns.selected_category_id

      assign(socket,
        page_title: "Editar Transação",
        budget: budget,
        transaction: transaction,
        form_action: :edit,
        show_form_modal: true,
        show_pending_transactions_drawer: false,
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
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    transaction =
      Finance.get_transaction(current_scope, id, socket.assigns.budget)

    case Finance.delete_transaction(current_scope, transaction) do
      {:ok, _deleted} ->
        {:noreply, socket}

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
  def handle_event("validate", %{"transaction" => transaction_params}, socket) do
    value = Map.get(transaction_params, "value") |> parse_float()
    amount = Map.get(transaction_params, "amount") |> parse_float()
    total_value = value * amount
    params = Map.put(transaction_params, "total_value", total_value)

    new_selected_category_id =
      Map.get(transaction_params, "category_id") || socket.assigns.selected_category_id

    changeset =
      Finance.change_transaction(
        socket.assigns.current_scope,
        socket.assigns.transaction,
        socket.assigns.budget,
        params
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate),
       selected_category_id: new_selected_category_id
     )}
  end

  @impl true
  def handle_event("save", %{"transaction" => transaction_params}, socket) do
    save_transaction(socket, socket.assigns.form_action, transaction_params)
  end

  @impl true
  def handle_event("show_pending_transactions_drawer", _params, socket) do
    {:noreply,
     assign(socket,
       show_pending_transactions_drawer: true,
       transaction: nil,
       form_action: nil
     )}
  end

  @impl true
  def handle_event("close_pending_transactions_drawer", _params, socket) do
    {:noreply,
     assign(socket,
       show_pending_transactions_drawer: false,
       transaction: nil,
       form_action: nil
     )}
  end

  @impl true
  def handle_info({:saved, transaction}, socket) do
    {:noreply,
     socket
     |> stream_insert(:transaction_collection, transaction)
     |> assign(show_form_modal: false, transaction: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets/#{socket.assigns.budget.id}/transactions")}
  end

  @impl true
  def handle_info({:deleted, transaction}, socket) do
    {:noreply,
     socket
     |> stream_delete(:transaction_collection, transaction)}
  end

  @impl true
  def handle_info(:transactions_updated, socket) do
    transactions =
      Finance.list_transactions(socket.assigns.current_scope, socket.assigns.budget)

    {:noreply,
     socket
     |> stream(:transaction_collection, transactions)}
  end

  defp save_transaction(socket, :edit, transaction_params) do
    value = Map.get(transaction_params, "value") |> parse_float()
    amount = Map.get(transaction_params, "amount") |> parse_float()
    total_value = value * amount

    transaction_params =
      if String.to_integer(transaction_params["category_id"]) !=
           socket.assigns.investment_category_id do
        Map.put(transaction_params, "investment_type_id", nil)
      else
        transaction_params
      end

    transaction_params = Map.put(transaction_params, "total_value", total_value)

    case Finance.update_transaction(
           socket.assigns.current_scope,
           socket.assigns.transaction,
           transaction_params
         ) do
      {:ok, transaction} ->
        send(self(), {:saved, transaction})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_transaction(socket, :new, transaction_params) do
    value = Map.get(transaction_params, "value") |> parse_float()
    amount = Map.get(transaction_params, "amount") |> parse_float()
    total_value = value * amount

    case Finance.create_transaction(
           socket.assigns.current_scope,
           Map.put(transaction_params, "total_value", total_value),
           socket.assigns.budget
         ) do
      {:ok, _transaction} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Transaction Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {number, _} -> number
      :error -> 0.0
    end
  end

  defp parse_float(_), do: 0.0

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
