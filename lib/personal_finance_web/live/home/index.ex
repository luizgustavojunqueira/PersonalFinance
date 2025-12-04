defmodule PersonalFinanceWeb.HomeLive.Index do
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

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
      Finance.subscribe_finance(:transaction, ledger.id)
      Finance.subscribe_finance(:category, ledger.id)

      data_transactions = Finance.list_transactions(current_scope, ledger, %{}, 0, :all)

      transactions = data_transactions.entries

      categories = Finance.list_categories(current_scope, ledger)

      today = Date.utc_today()
      ledger_month_note =
        Finance.get_ledger_month_note(current_scope, ledger, today.year, today.month)
        |> PersonalFinance.Finance.LedgerMonthNote.changeset(%{})
        |> Phoenix.Component.to_form(as: :ledger_month_note)

      socket =
        socket
        |> assign(
          current_user: current_scope.user,
          ledger: ledger,
          page_title: "#{gettext("Home")} #{ledger.name}",
          show_welcome_message: true,
          transactions: transactions,
          categories: categories,
          ledger_month_note: ledger_month_note,
          show_month_notes: false,
          profiles:
            Enum.map(Finance.list_profiles(current_scope, ledger), fn profile ->
              {profile.name, profile.id}
            end),
          form: to_form(%{"profile_id" => nil}),
          profile_id: nil
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("select_profile", %{"profile_id" => profile_id_str}, socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger

    profile_id = if profile_id_str == "", do: nil, else: String.to_integer(profile_id_str)

    data_transactions =
      Finance.list_transactions(
        current_scope,
        ledger,
        %{
          "profile_id" => profile_id
        },
        0,
        :all
      )

    transactions = data_transactions.entries

    {:noreply,
     assign(socket,
       transactions: transactions,
       profile_id: profile_id
     )}
  end

  @impl true
  def handle_event("open_month_notes", _params, socket) do
    {:noreply, assign(socket, :show_month_notes, true)}
  end

  @impl true
  def handle_event("close_month_notes", _params, socket) do
    {:noreply, assign(socket, :show_month_notes, false)}
  end

  @impl true
  def handle_event("save_month_note", %{"ledger_month_note" => params}, socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger

    attrs = params

    case Finance.upsert_ledger_month_note(current_scope, ledger, attrs) do
      {:ok, note} ->
        {:noreply,
         socket
         |> assign(
           :ledger_month_note,
           note |> PersonalFinance.Finance.LedgerMonthNote.changeset(%{}) |> Phoenix.Component.to_form(as: :ledger_month_note)
         )
         |> put_flash(:info, gettext("Monthly note saved."))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:ledger_month_note, Phoenix.Component.to_form(changeset, as: :ledger_month_note))
         |> put_flash(:error, gettext("Failed to save monthly note."))}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:saved, %PersonalFinance.Finance.Transaction{} = new_transaction}, socket) do
    updated_transactions =
      Enum.map(socket.assigns.transactions, fn t ->
        if t.id == new_transaction.id, do: new_transaction, else: t
      end)

    final_transactions =
      if Enum.any?(updated_transactions, &(&1.id == new_transaction.id)) do
        updated_transactions
      else
        [new_transaction | updated_transactions]
      end

    {:noreply,
     assign(socket,
       transactions: final_transactions
     )}
  end

  @impl true
  def handle_info(
        {:deleted, %PersonalFinance.Finance.Transaction{} = deleted_transaction},
        socket
      ) do
    updated_transactions =
      Enum.reject(socket.assigns.transactions, fn t -> t.id == deleted_transaction.id end)

    {:noreply,
     assign(socket,
       transactions: updated_transactions
     )}
  end

  @impl true
  def handle_info({:saved, %PersonalFinance.Finance.Category{} = new_category}, socket) do
    updated_categories =
      Enum.map(socket.assigns.categories, fn c ->
        if c.id == new_category.id, do: new_category, else: c
      end)

    final_categories =
      if Enum.any?(updated_categories, &(&1.id == new_category.id)) do
        updated_categories
      else
        [new_category | updated_categories]
      end

    {:noreply,
     assign(socket,
       categories: final_categories
     )}
  end

  @impl true
  def handle_info({:deleted, %PersonalFinance.Finance.Category{} = deleted_category}, socket) do
    # Remove a categoria da lista
    updated_categories =
      Enum.reject(socket.assigns.categories, fn c -> c.id == deleted_category.id end)

    {:noreply,
     assign(socket,
       categories: updated_categories
     )}
  end

  @impl true
  def handle_info(:transactions_updated, socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger

    data_transactions = Finance.list_transactions(current_scope, ledger)

    updated_transactions = data_transactions.entries

    {:noreply,
     assign(socket,
       transactions: updated_transactions
     )}
  end
end
