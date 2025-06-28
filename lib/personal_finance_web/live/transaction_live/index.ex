defmodule PersonalFinanceWeb.TransactionLive.Index do
  use PersonalFinanceWeb, :live_view
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    transactions =
      from(t in PersonalFinance.Transaction, order_by: [desc: t.date])
      |> Ecto.Query.preload([:category, :investment_type, :profile])
      |> PersonalFinance.Repo.all()

    categories = PersonalFinance.Category |> PersonalFinance.Repo.all()

    investment_category =
      PersonalFinance.Category
      |> PersonalFinance.Repo.get_by(name: "Investimentos")

    investment_types = PersonalFinance.InvestmentType |> PersonalFinance.Repo.all()

    profiles = PersonalFinance.Profile |> PersonalFinance.Repo.all()

    changeset = PersonalFinance.Transaction.changeset(%PersonalFinance.Transaction{}, %{})

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

    params = Map.put(transaction_params, "total_value", total_value)

    changeset =
      PersonalFinance.Transaction.changeset(%PersonalFinance.Transaction{}, params)

    case PersonalFinance.Repo.insert(changeset) do
      {:ok, added} ->
        new_changeset = PersonalFinance.Transaction.changeset(%PersonalFinance.Transaction{}, %{})

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
      PersonalFinance.Transaction.changeset(
        socket.assigns.selected_transaction || %PersonalFinance.Transaction{},
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

    changeset =
      PersonalFinance.Transaction.changeset(t, params)

    case PersonalFinance.Repo.update(changeset) do
      {:ok, updated} ->
        new_changeset = PersonalFinance.Transaction.changeset(%PersonalFinance.Transaction{}, %{})

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
    transaction = PersonalFinance.Repo.get(PersonalFinance.Transaction, String.to_integer(id))
    changeset = PersonalFinance.Transaction.changeset(transaction, %{})

    {:noreply,
     assign(socket,
       selected_transaction: transaction,
       show_form: true,
       changeset: changeset
     )}
  end

  @impl true
  def handle_info({:delete_transaction, id}, socket) do
    transaction = PersonalFinance.Repo.get(PersonalFinance.Transaction, String.to_integer(id))

    case PersonalFinance.Repo.delete(transaction) do
      {:ok, deleted} ->
        {:noreply, stream_delete(socket, :transactions, deleted)}

      {:error, _changeset} ->
        {:noreply, socket}
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
end
