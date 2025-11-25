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
       |> put_flash(:error, gettext("Ledger not found."))
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
         page_title: "#{gettext("Fixed Income")} - #{ledger.name}",
         ledger: ledger,
         open_modal: nil,
          fixed_income: nil,
          has_fixed_incomes: not Enum.empty?(fixed_incomes)
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
  def handle_event("open_edit_modal", %{"id" => fixed_income_id}, socket) do
    ledger = socket.assigns.ledger

    fixed_income = Investment.get_fixed_income(fixed_income_id, ledger.id)

    if fixed_income do
      {:noreply,
       assign(socket,
         open_modal: :edit_fixed_income,
         fixed_income: fixed_income
       )}
    else
      {:noreply, put_flash(socket, :error, gettext("Fixed income not found."))}
    end
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
     |> assign(has_fixed_incomes: true)
     |> put_flash(:info, gettext("Fixed income successfully saved."))}
  end
end
