defmodule PersonalFinanceWeb.FixedIncomeLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Investment
  alias PersonalFinance.Finance
  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Utils.CurrencyUtils

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
      fixed_incomes = Investment.list_fixed_incomes(ledger)

      {:ok,
       assign(socket,
         page_title: "Renda Fixa - #{ledger.name}",
         ledger: ledger,
         fixed_incomes: fixed_incomes
       )}
    end
  end
