defmodule PersonalFinanceWeb.TransactionController do
  use PersonalFinanceWeb, :controller

  alias Ecto.Repo.Transaction
  alias PersonalFinance.Transaction

  def index(conn, _params) do
    transactions = PersonalFinance.Repo.all(Transaction)
    changeset = Transaction.changeset(%Transaction{}, %{})
    render(conn, :index, transactions: transactions, changeset: changeset)
  end

  def create(conn, %{"transaction" => transaction_params}) do
    changeset = Transaction.changeset(%Transaction{}, transaction_params)

    case PersonalFinance.Repo.insert(changeset) do
      {:ok, _transaction} ->
        conn
        |> put_flash(:info, "Transaction created successfully.")
        |> redirect(to: ~p"/transactions")

      {:error, changeset} ->
        transactions = PersonalFinance.Repo.all(Transaction)
        render(conn, :index, transactions: transactions, changeset: changeset)
    end
  end
end
