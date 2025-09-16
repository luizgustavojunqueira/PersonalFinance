defmodule PersonalFinanceWeb.TransactionController do
  use PersonalFinanceWeb, :controller
  alias PersonalFinance.Finance

  def export(conn, %{"token" => token}) do
    case Phoenix.Token.verify(PersonalFinanceWeb.Endpoint, "export", token, max_age: 300) do
      {:ok, params} ->
        {:ok, csv_content} =
          Finance.export_transactions(
            params.ledger_id,
            params.filter
          )

        filename = "transactions_#{Date.utc_today()}.csv"

        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> send_resp(200, csv_content)

      {:error, _} ->
        conn
        |> put_flash(:error, "Link de download expirado")
        |> redirect(to: ~p"/transactions")
    end
  end
end
