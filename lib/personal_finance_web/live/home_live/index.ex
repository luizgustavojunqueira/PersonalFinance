defmodule PersonalFinanceWeb.HomeLive.Index do
  alias PersonalFinance.Balance
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

      chart_type = :bars

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
          form: to_form(%{"profile_id" => nil}),
          chart_type: chart_type,
          form_chart: to_form(%{"chart_type" => chart_type}),
          chart_option: get_chart_data(chart_type, categories, transactions),
          profile_id: nil
        )
        |> assign_balance()

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("select_chart_type", %{"chart_type" => chart_type}, socket) do
    transactions = socket.assigns.transactions
    categories = socket.assigns.categories

    {:noreply,
     assign(socket,
       chart_type: String.to_existing_atom(chart_type),
       chart_option:
         get_chart_data(String.to_existing_atom(chart_type), categories, transactions),
       form_chart: to_form(%{"chart_type" => chart_type})
     )}
  end

  @impl true
  def handle_event("select_profile", %{"profile_id" => profile_id_str}, socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger

    profile_id = if profile_id_str == "", do: nil, else: String.to_integer(profile_id_str)

    transactions = Finance.list_transactions(current_scope, ledger, profile_id)

    {:noreply,
     assign(socket,
       transactions: transactions,
       chart_option:
         get_chart_data(socket.assigns.chart_type, socket.assigns.categories, transactions),
       form: to_form(%{"profile_id" => profile_id_str}),
       profile_id: profile_id
     )
     |> assign_balance()}
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
       chart_option:
         get_chart_data(socket.assigns.chart_type, socket.assigns.categories, final_transactions)
     )
     |> assign_balance()}
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
       transactions: updated_transactions,
       chart_option:
         get_chart_data(
           socket.assigns.chart_type,
           socket.assigns.categories,
           updated_transactions
         )
     )
     |> assign_balance()}
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
       chart_option:
         get_chart_data(socket.assigns.chart_type, final_categories, socket.assigns.transactions)
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
       chart_option:
         get_chart_data(
           socket.assigns.chart_type,
           updated_categories,
           socket.assigns.transactions
         )
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
       chart_option:
         get_chart_data(
           socket.assigns.chart_type,
           socket.assigns.categories,
           updated_transactions
         )
     )
     |> assign_balance()}
  end

  defp assign_balance(socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger
    profile_id = socket.assigns.profile_id

    new_balance = Balance.get_balance(current_scope, ledger.id, :all, profile_id)
    new_month_balance = Balance.get_balance(current_scope, ledger.id, :monthly, profile_id)

    assign(socket,
      balance: new_balance,
      month_balance: new_month_balance
    )
  end

  defp get_chart_data(:pie, categories, transactions) do
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

  defp get_chart_data(:bars, categories, transactions) do
    categories_data =
      categories
      |> Enum.sort()
      |> Enum.map(fn category ->
        total =
          Enum.reduce(transactions, 0, fn t, acc ->
            if t.category_id == category.id, do: acc + t.total_value, else: acc
          end)

        %{
          id: category.id,
          name: category.name,
          percentage: category.percentage,
          total: total,
          goal: category.percentage * 1000 / 100,
          remaining:
            if(category.name == "Sem Categoria",
              do: 0,
              else: category.percentage * 5000 / 100 - total
            )
        }
      end)

    %{
      tooltip: %{
        trigger: "axis",
        axisPointer: %{
          type: "shadow"
        },
        formatter: "Categoria: {b0}<br/>Meta: {c2}<br/>Gasto: {c1}<br/>Restante: {c0}"
      },
      legend: %{
        data: ["Restante", "Gasto", "Meta"]
      },
      grid: %{
        left: "0%",
        right: "10%",
        bottom: "0%",
        containLabel: true
      },
      xAxis: [
        %{
          type: "value",
          axisLabel: %{
            formatter: "R$ {value}"
          },
          splitLine: %{
            lineStyle: %{
              color: "#eee",
              type: "dotted"
            }
          }
        }
      ],
      yAxis: [
        %{
          type: "category",
          axisTick: %{
            show: true
          },
          data: categories_data |> Enum.map(& &1.name),
          axisLabel: %{
            color: "#000",
            fontSize: 12,
            overflow: "truncate",
            width: 100,
            interval: 0
          },
          axisLine: %{
            show: false
          }
        }
      ],
      series: [
        %{
          name: "Restante",
          type: "bar",
          stack: "total_sum",
          itemStyle: %{
            color: "#4CAF50"
          },
          label: %{
            show: true,
            position: "insideRight",
            formatter: nil,
            color: "#000",
            textShadowBlur: 5,
            textShadowColor: "rgba(0, 0, 0, 0.3)"
          },
          emphasis: %{
            focus: "series"
          },
          data: categories_data |> Enum.map(& &1.remaining)
        },
        %{
          name: "Gasto",
          type: "bar",
          stack: "total_sum",
          itemStyle: %{
            color: "#FF9800"
          },
          label: %{
            show: true,
            position: "insideLeft",
            formatter: "R${@value}",
            color: "#fff",
            textShadowBlur: 5,
            textShadowColor: "rgba(0, 0, 0, 0.3)"
          },
          emphasis: %{
            focus: "series"
          },
          data: categories_data |> Enum.map(& &1.total)
        },
        %{
          name: "Meta",
          type: "bar",
          itemStyle: %{
            color: "rgba(0,0,0,0.2)",
            borderType: "dashed",
            borderColor: "#9E9E9E",
            borderWidth: 1
          },
          label: %{
            show: true,
            position: "insideRight",
            formatter: nil,
            color: "#fff"
          },
          emphasis: %{
            focus: "series"
          },
          z: 0,
          data: categories_data |> Enum.map(& &1.goal)
        }
      ]
    }
  end
end
