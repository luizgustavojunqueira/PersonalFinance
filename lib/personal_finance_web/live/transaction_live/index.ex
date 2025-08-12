defmodule PersonalFinanceWeb.TransactionLive.Index do
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

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
          Finance.subscribe_finance(:transaction, ledger.id)
          assign(socket, subscribed: true)
        end

      investment_types = Finance.list_investment_types()
      profiles = Finance.list_profiles(current_scope, ledger)
      categories = Finance.list_categories(current_scope, ledger)

      socket =
        socket
        |> assign(
          show_pending_transactions_drawer: false,
          categories: Enum.map(categories, fn category -> {category.name, category.id} end),
          investment_types: Enum.map(investment_types, fn type -> {type.name, type.id} end),
          profiles: Enum.map(profiles, fn profile -> {profile.name, profile.id} end),
          show_import_modal: false,
          transaction: nil,
          open_modal: nil,
          filter: %{
            "category_id" => nil,
            "profile_id" => nil,
            "investment_type_id" => nil,
            "start_date" => nil,
            "end_date" => nil
          }
        )

      {:ok, assign(socket, page_title: "Transações - #{ledger.name}", ledger: ledger)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_new_transaction", _, socket) do
    {:noreply, assign(socket, open_modal: :new_transaction, transaction: nil)}
  end

  @impl true
  def handle_event("open_edit_transaction", %{"transaction_id" => transaction_id}, socket) do
    transaction =
      Finance.get_transaction(socket.assigns.current_scope, transaction_id, socket.assigns.ledger)

    if transaction == nil do
      {:noreply,
       socket
       |> put_flash(:error, "Transação não encontrada.")}
    else
      {:noreply,
       assign(socket,
         open_modal: :edit_transaction,
         transaction: transaction
       )}
    end
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    IO.inspect(socket.assigns.open_modal, label: "Closing modal")
    {:noreply, assign(socket, open_modal: nil, transaction: nil)}
  end

  @impl true
  def handle_event("toggle_pending_transactions_drawer", _params, socket) do
    {:noreply,
     assign(socket,
       show_pending_transactions_drawer: not socket.assigns.show_pending_transactions_drawer,
       transaction: nil
     )}
  end

  @impl true
  def handle_event("toggle_import_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_import_modal: not socket.assigns.show_import_modal,
       transaction: nil
     )}
  end

  @impl true
  def handle_info({:apply_filter, filter}, socket) do
    send_update(PersonalFinanceWeb.TransactionLive.Transactions,
      id: "transactions-list",
      action: :update,
      filter: filter
    )

    {:noreply, assign(socket, :filters, filter)}
  end

  @impl true
  def handle_info({:deleted, transaction}, socket) do
    send_update(PersonalFinanceWeb.TransactionLive.Transactions,
      id: "transactions-list",
      action: :deleted,
      transaction: transaction
    )

    {:noreply,
     socket
     |> put_flash(:info, "Transação removida com sucesso.")}
  end

  @impl true
  def handle_info({:saved, transaction}, socket) do
    send_update(PersonalFinanceWeb.TransactionLive.Transactions,
      id: "transactions-list",
      action: :saved,
      transaction: transaction
    )

    {:noreply,
     socket
     |> assign(open_modal: nil, transaction: nil)
     |> put_flash(:info, "Transação salva com sucesso.")
     |> push_patch(to: ~p"/ledgers/#{socket.assigns.ledger.id}/transactions")}
  end

  @impl true
  def handle_info(:transactions_updated, socket) do
    send_update(PersonalFinanceWeb.TransactionLive.Transactions,
      id: "transactions-list",
      action: :update
    )

    {:noreply, socket}
  end
end
