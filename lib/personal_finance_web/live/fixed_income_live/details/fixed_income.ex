defmodule PersonalFinanceWeb.FixedIncomeLive.Details.FixedIncome do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Investment
  alias PersonalFinance.Finance

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope
    ledger = Finance.get_ledger(current_scope, params["id"])
    fixed_income = Investment.get_fixed_income(params["fixed_income_id"], ledger.id)

    if ledger == nil or fixed_income == nil do
      {:ok,
       socket
       |> put_flash(:error, "Orçamento ou Renda Fixa não encontrado.")
       |> push_navigate(to: ~p"/ledgers")}
    else

      {:ok,
       socket
       |> assign(
         page_title: "Renda Fixa - #{fixed_income.name}",
         ledger: ledger,
         fixed_income: fixed_income
       )}
    end
  end
end
