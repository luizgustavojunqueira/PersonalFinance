defmodule PersonalFinanceWeb.TransactionLive.Index do
  alias PersonalFinance.Finance.{Transaction}
  alias PersonalFinance.Finance
  alias PersonalFinance.CurrencyUtils
  alias PersonalFinance.DateUtils
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope

    ledger = Finance.get_ledger(current_scope, params["id"])

    if ledger == nil do
      {:ok,
       socket
       |> put_flash(:error, "Orçamento não encontrado.")
       |> push_navigate(to: ~p"/ledgers")}
    else
      socket =
        if not Map.get(socket.assigns, :subscribed, false) do
          Finance.subscribe_finance(:transaction, ledger.id)
          assign(socket, subscribed: true)
        end

      categories = Finance.list_categories(current_scope, ledger)

      investment_category =
        Finance.get_category_by_name("Investimento", socket.assigns.current_scope, ledger)

      investment_types = Finance.list_investment_types()

      profiles = Finance.list_profiles(socket.assigns.current_scope, ledger)

      socket =
        socket
        |> assign(
          categories: Enum.map(categories, fn category -> {category.name, category.id} end),
          investment_category_id: if(investment_category, do: investment_category.id, else: nil),
          investment_types: Enum.map(investment_types, fn type -> {type.name, type.id} end),
          profiles: Enum.map(profiles, fn profile -> {profile.name, profile.id} end),
          selected_category_id: nil,
          show_pending_transactions_drawer: false,
          filter: %{
            "category_id" => nil,
            "profile_id" => nil,
            "investment_type_id" => nil,
            "start_date" => nil,
            "end_date" => nil
          }
        )

      {:ok, socket |> apply_action(socket.assigns.live_action, params, ledger)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> apply_action(socket.assigns.live_action, params, socket.assigns.ledger)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params, ledger) do
    assign(socket,
      page_title: "Transações - #{ledger.name}",
      ledger: ledger,
      show_form_modal: false,
      transaction: nil,
      selected_category_id: nil
    )
  end

  defp apply_action(socket, :new, _params, ledger) do
    transaction = %Transaction{ledger_id: ledger.id}

    assign(socket,
      page_title: "Nova Transação",
      ledger: ledger,
      transaction: transaction,
      form_action: :new,
      show_form_modal: true,
      form:
        to_form(
          Finance.change_transaction(
            socket.assigns.current_scope,
            %Transaction{ledger_id: ledger.id},
            ledger
          )
        )
    )
  end

  defp apply_action(socket, :edit, %{"transaction_id" => transaction_id}, ledger) do
    transaction =
      Finance.get_transaction(socket.assigns.current_scope, transaction_id, ledger)

    if transaction == nil do
      socket
      |> put_flash(:error, "Transação não encontrada.")
      |> push_navigate(to: ~p"/ledgers/#{ledger.id}/transactions")
    else
      selected_category_id =
        transaction.category_id ||
          socket.assigns.selected_category_id

      assign(socket,
        page_title: "Editar Transação",
        ledger: ledger,
        transaction: transaction,
        form_action: :edit,
        show_form_modal: true,
        selected_category_id: selected_category_id,
        form:
          to_form(
            Finance.change_transaction(
              socket.assigns.current_scope,
              transaction,
              ledger
            )
          )
      )
    end
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply,
     socket
     |> assign(show_form_modal: false, transaction: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers/#{socket.assigns.ledger.id}/transactions")}
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
        socket.assigns.ledger,
        params
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate),
       selected_category_id: new_selected_category_id
     )}
  end

  @impl true
  def handle_event("toggle_pending_transactions_drawer", _params, socket) do
    {:noreply,
     assign(socket,
       show_pending_transactions_drawer: not socket.assigns.show_pending_transactions_drawer,
       transaction: nil,
       form_action: nil
     )}
  end

  @impl true
  def handle_event("save", %{"transaction" => transaction_params}, socket) do
    save_transaction(socket, socket.assigns.form_action, transaction_params)
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
      {:ok, _transaction} ->
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
           socket.assigns.ledger
         ) do
      {:ok, _transaction} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Transaction Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_info({:apply_filter, filter}, socket) do
    send_update(PersonalFinanceWeb.TransactionLive.Transactions,
      id: "transactions-list",
      action: :update,
      filter: filter
    )

    socket =
      socket
      |> assign(:filters, filter)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:deleted, transaction}, socket) do
    send_update(PersonalFinanceWeb.TransactionLive.Transactions,
      id: "transactions-list",
      action: :deleted,
      transaction: transaction
    )

    {:noreply,
     socket
     |> put_flash(:info, "Transação removida com sucesso.")}
  end

  @impl true
  def handle_info({:saved, transaction}, socket) do
    send_update(PersonalFinanceWeb.TransactionLive.Transactions,
      id: "transactions-list",
      action: :saved,
      transaction: transaction
    )

    {:noreply,
     socket
     |> assign(show_form_modal: false, transaction: nil, form_action: nil)
     |> put_flash(:info, "Transação salva com sucesso.")
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers/#{socket.assigns.ledger.id}/transactions")}
  end

  @impl true
  def handle_info(:transactions_updated, socket) do
    send_update(PersonalFinanceWeb.TransactionLive.Transactions,
      id: "transactions-list",
      action: :update
    )

    {:noreply, socket}
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
end
