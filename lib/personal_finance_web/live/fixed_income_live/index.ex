defmodule PersonalFinanceWeb.FixedIncomeLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Investment
  alias PersonalFinance.Finance

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
          Finance.subscribe_finance(:fixed_income, ledger.id)
          assign(socket, subscribed: true)
        end

      fixed_incomes = Investment.list_fixed_incomes(ledger)

      {:ok,
       socket
       |> stream(:fixed_income_collection, fixed_incomes)
       |> assign(
         page_title: "Renda Fixa - #{ledger.name}",
         ledger: ledger,
         open_modal: nil
       )}
    end
  end

  @impl true
  def handle_event("open_modal", %{"modal" => modal}, socket) do
    modal_atom = String.to_existing_atom(modal)
    socket = assign(socket, open_modal: modal_atom, fixed_income: nil)
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, open_modal: nil)}
  end

  @impl true
  def handle_info({:saved, fixed_income}, socket) do
    {:noreply,
     socket
     |> assign(open_modal: nil)
     |> stream_insert(:fixed_income_collection, fixed_income)
     |> put_flash(:info, "Renda Fixa salva com sucesso.")}
  end
end
