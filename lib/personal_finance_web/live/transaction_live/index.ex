defmodule PersonalFinanceWeb.TransactionLive.Index do
  alias PersonalFinance.Finance.{Transaction}
  alias PersonalFinance.PubSub
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    if current_user do
      Phoenix.PubSub.subscribe(
        PubSub,
        "transactions_updates:#{current_user.id}"
      )
    end

    transactions = Finance.list_transactions_for_user(current_user)

    categories = Finance.list_categories_for_user(current_user)

    investment_category = Finance.get_category_by_name("Investimentos")

    investment_types = Finance.list_investment_types()

    profiles = Finance.list_profiles_for_user(current_user)

    changeset = Transaction.changeset(%Transaction{}, %{})

    socket =
      socket
      |> assign(
        changeset: changeset,
        selected_transaction: nil,
        show_form: false,
        categories: Enum.map(categories, fn category -> {category.name, category.id} end),
        selected_category_id: nil,
        investment_category_id: if(investment_category, do: investment_category.id, else: nil),
        investment_types: Enum.map(investment_types, fn type -> {type.name, type.id} end),
        profiles: Enum.map(profiles, fn profile -> {profile.name, profile.id} end)
      )
      |> stream(:transactions, transactions, id: & &1.id)

    {:ok, socket}
  end

  @impl true
  def handle_event("create_transaction", %{"transaction" => transaction_params}, socket) do
    value = Map.get(transaction_params, "value") |> parse_float()
    amount = Map.get(transaction_params, "amount") |> parse_float()
    total_value = value * amount

    current_user = socket.assigns.current_scope.user
    # Adiciona o user_id aos params antes de criar a transação
    params_with_user = Map.put(transaction_params, "user_id", current_user.id)

    case Finance.create_transaction(Map.put(params_with_user, "total_value", total_value)) do
      {:ok, added} ->
        new_changeset = Transaction.changeset(%Transaction{}, %{})

        {:noreply,
         socket
         |> stream_insert(:transactions, added)
         |> assign(
           changeset: new_changeset,
           selected_transaction: nil,
           show_form: false
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("validate_transaction", %{"transaction" => transaction_params}, socket) do
    value = Map.get(transaction_params, "value") |> parse_float()
    amount = Map.get(transaction_params, "amount") |> parse_float()
    total_value = value * amount
    params = Map.put(transaction_params, "total_value", total_value)

    new_selected_category_id =
      Map.get(transaction_params, "category_id") || socket.assigns.selected_category_id

    changeset =
      Transaction.changeset(
        socket.assigns.selected_transaction || %Transaction{},
        params
      )

    {:noreply,
     assign(socket,
       action: :validate,
       changeset: changeset,
       selected_category_id: new_selected_category_id
     )}
  end

  def handle_event("open_form", _params, socket) do
    {:noreply, assign(socket, show_form: true, selected_transaction: nil)}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, selected_transaction: nil)}
  end

  def handle_event("update_transaction", %{"transaction" => transaction_params}, socket) do
    t = socket.assigns.selected_transaction

    value = Map.get(transaction_params, "value") |> parse_float()
    amount = Map.get(transaction_params, "amount") |> parse_float()
    total_value = value * amount

    params = Map.put(transaction_params, "total_value", total_value)

    case Finance.update_transaction(t, params) do
      {:ok, updated} ->
        new_changeset = Transaction.changeset(%Transaction{}, %{})

        {:noreply,
         socket
         |> stream_insert(:transactions, updated)
         |> assign(
           changeset: new_changeset,
           selected_transaction: nil,
           show_form: false
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_info({:edit_transaction, id}, socket) do
    transaction = Finance.get_transaction!(String.to_integer(id))
    changeset = Transaction.changeset(transaction, %{})

    {:noreply,
     assign(socket,
       selected_transaction: transaction,
       show_form: true,
       changeset: changeset
     )}
  end

  @impl true
  def handle_info({:delete_transaction, id}, socket) do
    transaction = Finance.get_transaction!(String.to_integer(id))

    case Finance.delete_transaction(transaction) do
      {:ok, deleted} ->
        {:noreply, stream_delete(socket, :transactions, deleted)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:transaction_changed, user_id}, socket)
      when socket.assigns.current_scope.user.id == user_id do
    IO.puts(
      "Recebida notificação de mudança de transação para o usuário #{user_id}. Recarregando dados..."
    )

    transactions = Finance.list_transactions_for_user(socket.assigns.current_scope.user)

    # Atualize o stream ou o assign de transações
    socket =
      socket
      |> stream(:transactions, transactions)

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
