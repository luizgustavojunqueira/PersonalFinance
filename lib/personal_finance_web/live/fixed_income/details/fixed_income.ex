defmodule PersonalFinanceWeb.FixedIncomeLive.Details.FixedIncome do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Investment
  alias PersonalFinance.Finance
  alias PersonalFinance.Utils.CurrencyUtils

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
      socket =
        if not Map.get(socket.assigns, :subscribed, false) do
          Finance.subscribe_finance(:fixed_income_transaction, ledger.id, fixed_income.id)
          assign(socket, subscribed: true)
        end

      {:ok,
       socket
       |> assign(
         page_title: "Renda Fixa - #{fixed_income.name}",
         ledger: ledger,
         fixed_income: fixed_income,
         open_modal: nil
       )
       |> assign_values()}
    end
  end

  @impl true
  def handle_event("open_modal", %{"modal" => modal}, socket) do
    modal_atom = String.to_existing_atom(modal)
    socket = assign(socket, open_modal: modal_atom)
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, open_modal: nil)}
  end

  @impl true
  def handle_info({:saved, fi_transaction}, socket) do
    send_update(PersonalFinanceWeb.FixedIncomeLive.Details.FixedIncomeTransactions,
      id: "fixed-income-transactions",
      action: :saved,
      fixed_income_transaction: fi_transaction
    )

    {:noreply, socket |> assign_values() |> assign(open_modal: nil)}
  end

  def assign_values(socket) do
    {total_invested, total_yield, total_tax, total_value} =
      Investment.get_details(socket.assigns.fixed_income)

    socket
    |> assign(
      total_invested: total_invested,
      total_yield: total_yield,
      total_tax: total_tax,
      total_value: total_value
    )
  end
end
