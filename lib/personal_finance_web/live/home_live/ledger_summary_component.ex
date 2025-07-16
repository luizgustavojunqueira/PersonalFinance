defmodule PersonalFinanceWeb.HomeLive.LedgerSummaryComponent do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.DateUtils
  alias PersonalFinance.CurrencyUtils
  alias PersonalFinance.Balance
  alias PersonalFinance.Accounts.Scope

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-row gap-4 px-4">
      <div class="min-w-100 grid grid-rows-[1fr_2fr] gap-4 max-h-[calc(100vh-8rem)] overflow-y-auto">
        <div class="bg-light-green/50 text-xl font-bold rounded-lg p-6 px-8 flex flex-col items-left text-dark-green gap-4 ">
          <div class="flex flex-col">
            Saldo Atual
            <span class="text-3xl font-bold text-black">
              {@balance.balance |> CurrencyUtils.format_money()}
            </span>
          </div>

          <div class="flex flex-col">
            Saldo Mensal
            <div class="flex flex-col gap-1">
              <span class="text-xl font-bold text-green-600">
                + {@month_balance.total_incomes |> CurrencyUtils.format_money()}
              </span>
              <span class="text-xl font-bold text-red-600">
                - {@month_balance.total_expenses |> CurrencyUtils.format_money()}
              </span>
              <span class={[
                "text-3xl font-bold text-dark-green",
                if(@month_balance.balance < 0, do: " text-red-700", else: " text-green-700")
              ]}>
                {@month_balance.balance |> CurrencyUtils.format_money()}
              </span>
            </div>
          </div>
        </div>

        <div class="bg-medium-green/40 text-xl font-bold rounded-lg flex flex-col items-left text-dark-green gap-2 h-fit ">
          <div class="flex flex-col p-4">
            Transações Recentes
            <span class="text-sm text-gray-600">
              <.link
                class="text-blue-600 hover:text-blue-800"
                navigate={~p"/ledgers/#{@ledger.id}/transactions"}
              >
                Ver todas
              </.link>
            </span>
          </div>

          <div class="flex flex-col">
            <div
              :for={{id, transaction} <- @streams.recent_transactions}
              class="flex flex-row justify-between items-center bg-light-green/40 p-4 gap-2"
              id={id}
            >
              <div class="flex flex-row gap-4 items-center">
                <.icon name="hero-banknotes" class="text-2xl text-dark-green" />
                <div class="flex flex-col ">
                  <span class="text-lg font-semibold">{transaction.description}</span>
                  <span class="text-sm font-semibold">{transaction.profile.name}</span>
                </div>
              </div>
              <div class="flex flex-col ">
                <span class="text-lg font-bold text-dark-green">
                  {CurrencyUtils.format_money(transaction.total_value)}
                </span>
                <span class="text-sm text-gray-600">
                  {DateUtils.format_date(transaction.date)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="min-w-100 bg-light-green/40 text-xl font-bold rounded-lg p-4 flex flex-col items-left text-dark-green gap-4 h-fit ">
        <div class="flex flex-row justify-between items-center">
          Análise Mensal
          <.form
            id="chart_select_form"
            for={@form_chart}
            phx-change="select_chart_type"
            phx-target={@myself}
          >
            <.input
              type="select"
              field={@form_chart[:chart_type]}
              options={[{"Barras", :bars}, {"Pizza", :pie}]}
            />
          </.form>
        </div>

        <%= if @chart_type == :pie do %>
          <div id="pie" phx-hook="Chart">
            <div id="pie-chart" class="min-w-150 min-h-120" phx-update="ignore" />
            <div id="pie-data" hidden>{Jason.encode!(@chart_option)}</div>
          </div>
        <% else %>
          <%= if @chart_type == :bars do %>
            <div id="bar" phx-hook="Chart">
              <div id="bar-chart" class="min-w-150 min-h-120" phx-update="ignore" />
              <div id="bar-data" hidden>{Jason.encode!(@chart_option)}</div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    chart_type = :bars

    {:ok,
     socket
     |> assign(
       chart_type: chart_type,
       form_chart: to_form(%{"chart_type" => chart_type})
     )
     |> stream(:recent_transactions, [])}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_balance()
     |> assign_chart_data()
     |> stream(:recent_transactions, assigns.transactions |> Enum.take(5))}
  end

  @impl true
  def handle_event("select_chart_type", %{"chart_type" => chart_type}, socket) do
    transactions = socket.assigns.transactions
    categories = socket.assigns.categories

    {:noreply,
     assign(socket,
       chart_type: String.to_existing_atom(chart_type),
       chart_option:
         categories
         |> format_categories(transactions)
         |> get_chart_data(String.to_existing_atom(chart_type)),
       form_chart: to_form(%{"chart_type" => chart_type})
     )}
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

  defp assign_chart_data(socket) do
    chart_type = socket.assigns.chart_type || :bars
    categories = socket.assigns.categories || []
    transactions = socket.assigns.transactions || []

    chart_data =
      categories
      |> format_categories(transactions)
      |> get_chart_data(chart_type)

    assign(socket, chart_option: chart_data)
  end

  defp format_categories(categories, transactions) do
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
  end

  defp get_chart_data(categories_data, :pie) do
    option = %{
      tooltip: %{
        trigger: "item"
      },
      legend: %{
        top: "0",
        left: "left",
        textStyle: %{
          color: "#000",
          fontSize: 18
        }
      },
      series: [
        %{
          name: "Categoria",
          type: "pie",
          radius: ["20%", "50%"],
          itemStyle: %{
            borderRadius: 10,
            borderColor: "#fff",
            borderWidth: 1
          },
          label: %{
            show: true,
            position: "outside",
            formatter: "{b}: {d}%",
            color: "#000",
            fontSize: 14
          },
          emphasis: %{
            label: %{
              show: false
            }
          },
          labelLine: %{
            show: false
          },
          data:
            Enum.map(categories_data, fn category ->
              %{
                name: category.name,
                value: category.total,
                itemStyle: %{
                  color: "hsl(#{Enum.random(0..360)}, 70%, 50%)"
                }
              }
            end)
        }
      ]
    }

    option
  end

  defp get_chart_data(categories_data, :bars) do
    names = Enum.map(categories_data, & &1.name)
    remaining_values = Enum.map(categories_data, & &1.remaining)
    total_values = Enum.map(categories_data, & &1.total)
    goal_values = Enum.map(categories_data, & &1.goal)

    %{
      tooltip: %{
        trigger: "axis",
        axisPointer: %{
          type: "shadow"
        },
        formatter: "Categoria: {b0}<br/>Meta: {c2}<br/>Gasto: {c1}<br/>Restante: {c0}"
      },
      legend: %{
        data: ["Restante", "Gasto", "Meta"],
        textStyle: %{
          color: "#000",
          fontSize: 18
        }
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
          data: names,
          axisLabel: %{
            color: "#000",
            fontSize: 16,
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
            color: "#4CAF5099"
          },
          label: %{
            show: true,
            position: "insideRight",
            formatter: nil,
            color: "#111",
            textShadowBlur: 5,
            fontSize: 14,
            textShadowColor: "rgba(0, 0, 0, 0.3)"
          },
          emphasis: %{
            focus: "series"
          },
          data: remaining_values
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
            color: "#000",
            textShadowBlur: 5,
            fontSize: 14,
            textShadowColor: "rgba(0, 0, 0, 0.3)"
          },
          emphasis: %{
            focus: "series"
          },
          data: total_values
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
            fontSize: 14,
            color: "#000"
          },
          emphasis: %{
            focus: "series"
          },
          z: 0,
          data: goal_values
        }
      ]
    }
  end
end
