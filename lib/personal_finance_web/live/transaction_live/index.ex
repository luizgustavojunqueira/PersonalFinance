defmodule PersonalFinanceWeb.TransactionLive.Index do
  use PersonalFinanceWeb, :live_view
  import Ecto.Query

  def mount(_params, _session, socket) do
    transactions =
      from(t in PersonalFinance.Transaction, order_by: [desc: t.date])
      |> PersonalFinance.Repo.all()

    changeset = PersonalFinance.Transaction.changeset(%PersonalFinance.Transaction{}, %{})

    {:ok,
     assign(socket,
       transactions: transactions,
       changeset: changeset,
       selected_transaction: nil,
       show_form: false
     )}
  end

  def handle_event("create_transaction", %{"transaction" => transaction_params}, socket) do
    value = Map.get(transaction_params, "value") |> parse_float()
    amount = Map.get(transaction_params, "amount") |> parse_float()
    total_value = value * amount

    params = Map.put(transaction_params, :total_value, total_value)

    changeset =
      PersonalFinance.Transaction.changeset(%PersonalFinance.Transaction{}, params)

    case PersonalFinance.Repo.insert(changeset) do
      {:ok, _transaction} ->
        transactions =
          from(t in PersonalFinance.Transaction, order_by: [desc: t.date])
          |> PersonalFinance.Repo.all()

        new_changeset = PersonalFinance.Transaction.changeset(%PersonalFinance.Transaction{}, %{})

        {:noreply,
         assign(socket,
           transactions: transactions,
           changeset: new_changeset,
           selected_transaction: nil
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

    changeset =
      PersonalFinance.Transaction.changeset(
        socket.assigns.selected_transaction || %PersonalFinance.Transaction{},
        params
      )

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("delete_transaction", %{"id" => id}, socket) do
    transaction = PersonalFinance.Repo.get(PersonalFinance.Transaction, String.to_integer(id))

    case PersonalFinance.Repo.delete(transaction) do
      {:ok, _transaction} ->
        transactions =
          from(t in PersonalFinance.Transaction, order_by: [desc: t.date])
          |> PersonalFinance.Repo.all()

        {:noreply, assign(socket, transactions: transactions)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("edit_transaction", %{"id" => id}, socket) do
    transaction = PersonalFinance.Repo.get(PersonalFinance.Transaction, String.to_integer(id))
    changeset = PersonalFinance.Transaction.changeset(transaction, %{})

    {:noreply,
     assign(socket, selected_transaction: transaction, show_form: true, changeset: changeset)}
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
      {:ok, _transaction} ->
        transactions =
          from(t in PersonalFinance.Transaction, order_by: [desc: t.date])
          |> PersonalFinance.Repo.all()

        new_changeset = PersonalFinance.Transaction.changeset(%PersonalFinance.Transaction{}, %{})

        {:noreply,
         assign(socket,
           transactions: transactions,
           changeset: new_changeset,
           selected_transaction: nil,
           show_form: false
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def format_date(nil), do: "Data não disponível"
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")
  def format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  def format_date(_), do: "Data inválida"

  defp parse_float(nil), do: 0.0
  defp parse_float(""), do: 0.0

  defp parse_float(val) when is_binary(val) do
    val
    |> String.replace(",", ".")
    |> String.to_float()
  rescue
    _ -> 0.0
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(_), do: 0.0
end
