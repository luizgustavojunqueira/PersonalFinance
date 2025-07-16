defmodule PersonalFinanceWeb.HomeLive.Index do
  alias PersonalFinance.Finance
  alias PersonalFinance.CurrencyUtils
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
      Finance.subscribe_finance(:transaction, ledger.id)
      Finance.subscribe_finance(:category, ledger.id)

      transactions = Finance.list_transactions(current_scope, ledger)
      categories = Finance.list_categories(current_scope, ledger)

      socket =
        socket
        |> assign(
          current_user: current_scope.user,
          ledger: ledger,
          page_title: "Home #{ledger.name}",
          show_welcome_message: true,
          transactions: transactions,
          categories: categories,
          profiles:
            Enum.map(Finance.list_profiles(current_scope, ledger), fn profile ->
              {profile.name, profile.id}
            end),
          balance: Finance.get_balance(current_scope, ledger.id, nil),
          month_balance:
            Finance.get_month_balance(
              current_scope,
              ledger.id,
              Date.utc_today(),
              nil
            ),
          form: to_form(%{"profile_id" => nil}),
          chart_option: get_chart_data(categories, transactions)
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("select_profile", %{"profile_id" => profile_id_str}, socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger

    profile_id = if profile_id_str == "", do: nil, else: String.to_integer(profile_id_str)

    new_balance =
      Finance.get_balance(current_scope, ledger.id, profile_id)

    new_month_balance =
      Finance.get_month_balance(
        current_scope,
        ledger.id,
        Date.utc_today(),
        profile_id
      )

    transactions = Finance.list_transactions(current_scope, ledger, profile_id)

    {:noreply,
     assign(socket,
       month_balance: new_month_balance,
       balance: new_balance,
       transactions: transactions,
       chart_option: get_chart_data(socket.assigns.categories, transactions),
       form: to_form(%{"profile_id" => profile_id_str})
     )}
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
       transactions: final_transactions,
       balance:
         Finance.get_balance(
           socket.assigns.current_scope,
           socket.assigns.ledger.id,
           nil
         ),
       month_balance:
         Finance.get_month_balance(
           socket.assigns.current_scope,
           socket.assigns.ledger.id,
           Date.utc_today(),
           nil
         ),
       chart_option: get_chart_data(socket.assigns.categories, final_transactions)
     )}
  end

  @impl true
  def handle_info(
        {:deleted, %PersonalFinance.Finance.Transaction{} = deleted_transaction},
        socket
      ) do
    # Remove a transação da lista
    updated_transactions =
      Enum.reject(socket.assigns.transactions, fn t -> t.id == deleted_transaction.id end)

    {:noreply,
     assign(socket,
       transactions: updated_transactions,
       balance:
         Finance.get_balance(
           socket.assigns.current_scope,
           socket.assigns.ledger.id,
           nil
         ),
       month_balance:
         Finance.get_month_balance(
           socket.assigns.current_scope,
           socket.assigns.ledger.id,
           Date.utc_today(),
           nil
         ),
       chart_option: get_chart_data(socket.assigns.categories, updated_transactions)
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
       categories: final_categories,
       chart_option: get_chart_data(final_categories, socket.assigns.transactions)
     )}
  end

  @impl true
  def handle_info({:deleted, %PersonalFinance.Finance.Category{} = deleted_category}, socket) do
    # Remove a categoria da lista
    updated_categories =
      Enum.reject(socket.assigns.categories, fn c -> c.id == deleted_category.id end)

    {:noreply,
     assign(socket,
       categories: updated_categories,
       chart_option: get_chart_data(updated_categories, socket.assigns.transactions)
     )}
  end

  @impl true
  def handle_info(:transactions_updated, socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger

    updated_transactions = PersonalFinance.Finance.list_transactions(current_scope, ledger)

    {:noreply,
     assign(socket,
       transactions: updated_transactions,
       balance:
         Finance.get_balance(
           socket.assigns.current_scope,
           socket.assigns.ledger.id,
           nil
         ),
       month_balance:
         Finance.get_month_balance(
           socket.assigns.current_scope,
           socket.assigns.ledger.id,
           Date.utc_today(),
           nil
         ),
       chart_option: get_chart_data(socket.assigns.categories, updated_transactions)
     )}
  end

  defp get_chart_data(categories, transactions) do
    data =
      Enum.map(categories, fn category ->
        total =
          Enum.reduce(transactions, 0, fn t, acc ->
            if t.category_id == category.id, do: acc + t.total_value, else: acc
          end)

        %{name: category.name, value: total}
      end)
      |> Enum.filter(fn %{value: v} -> v > 0 end)

    option = %{
      tooltip: %{
        trigger: "item"
      },
      legend: %{
        top: "0",
        left: "left"
      },
      series: [
        %{
          name: "Categoria",
          type: "pie",
          radius: ["40%", "80%"],
          itemStyle: %{
            borderRadius: 10,
            borderColor: "#fff",
            borderWidth: 1
          },
          label: %{
            show: false
          },
          emphasis: %{
            label: %{
              show: false
            }
          },
          labelLine: %{
            show: false
          },
          data: data
        }
      ]
    }

    option
  end
end
