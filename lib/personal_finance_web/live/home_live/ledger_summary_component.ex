defmodule PersonalFinanceWeb.HomeLive.LedgerSummaryComponent do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.DateUtils
  alias PersonalFinance.CurrencyUtils
  alias PersonalFinance.Balance

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col xl:flex-row gap-4 px-4">
      <div class="min-w-100 grid grid-rows-[1fr_2fr] gap-4 h-full overflow-y-auto">
        <div class="bg-base-300 text-xl font-bold rounded-lg p-6 px-8 flex flex-col items-left text-dark-green gap-4 dark:text-white ">
          <div class="flex flex-col">
            Saldo Atual
            <span class="text-3xl font-bold text-black">
              {@balance.balance |> CurrencyUtils.format_money()}
            </span>
          </div>

          <div class="flex flex-col">
            Saldo Mensal
            <div class="flex flex-col gap-1">
              <span class="text-xl font-bold text-green-600 dark:text-green-400">
                + {@month_balance.total_incomes |> CurrencyUtils.format_money()}
              </span>
              <span class="text-xl font-bold text-red-600 dark:text-red-400">
                - {@month_balance.total_expenses |> CurrencyUtils.format_money()}
              </span>
              <span class={[
                "text-3xl font-bold",
                if(@month_balance.balance < 0,
                  do: " text-red-700",
                  else: " text-green-700"
                )
              ]}>
                {@month_balance.balance |> CurrencyUtils.format_money()}
              </span>
            </div>
          </div>
        </div>

        <div class="bg-base-300 text-xl font-bold rounded-lg flex flex-col items-left text-dark-green gap-2 h-fit dark:text-white ">
          <div class="flex flex-col p-4">
            Transações Recentes
            <span class="text-sm text-gray-600">
              <.link
                class="text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-600"
                navigate={~p"/ledgers/#{@ledger.id}/transactions"}
              >
                Ver todas
              </.link>
            </span>
          </div>

          <div class="flex flex-col">
            <div
              :for={{id, transaction} <- @streams.recent_transactions}
              class="flex flex-row justify-between items-center bg-base-100/50 p-4 gap-2 hover:bg-base-100 transition-colors text-dark-green dark:text-white "
              id={id}
            >
              <div class="flex flex-row gap-4 items-center">
                <.icon name="hero-banknotes" class="text-2xl" />
                <div class="flex flex-col ">
                  <span class="text-lg font-semibold">{transaction.description}</span>
                  <span class="text-sm font-semibold text-dark-green/70 dark:text-white/70">
                    {transaction.profile.name}
                  </span>
                </div>
              </div>
              <div class="flex flex-col ">
                <span class="text-lg font-bold ">
                  {CurrencyUtils.format_money(transaction.total_value)}
                </span>
                <span class="text-sm text-dark-green/70 dark:text-white/70">
                  {DateUtils.format_date(transaction.date)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="min-w-120 grid grid-rows-[2fr_1fr] gap-4 overflow-y-auto">
        <div class="bg-base-300 text-xl font-bold rounded-lg p-4 flex flex-col items-left text-dark-green dark:text-white gap-4 h-fit ">
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
              <div id="pie-chart" class="w-full h-96" phx-update="ignore" />
              <div id="pie-data" hidden>{Jason.encode!(@chart_option)}</div>
            </div>
          <% else %>
            <%= if @chart_type == :bars do %>
              <div id="bar" phx-hook="Chart">
                <div id="bar-chart" class="w-full h-96" phx-update="ignore" />
                <div id="bar-data" hidden>{Jason.encode!(@chart_option)}</div>
              </div>
            <% end %>
          <% end %>
        </div>

        <%= if !Enum.empty?(@messages) do %>
          <div class="bg-base-300 text-dark-green dark:text-white rounded-xl p-4 shadow-sm space-y-4 h-fit">
            <div class="flex items-center justify-between">
              <span class="text-xl font-semibold">Avisos</span>
            </div>

            <div class="space-y-2">
              <div
                :for={message <- @messages}
                class="flex items-center gap-3 bg-white/60 dark:bg-white/10 rounded-lg p-3 hover:bg-white/80 dark:hover:bg-white/20 transition-colors"
              >
                <.icon
                  name={
                    case message.type do
                      :info -> "hero-information-circle"
                      :warning -> "hero-exclamation-circle"
                      :error -> "hero-x-circle"
                    end
                  }
                  class={
                  "w-5 h-5 " <>
                    case message.type do
                      :info -> "text-blue-500 dark:text-blue-400"
                      :warning -> "text-yellow-500 dark:text-yellow-400"
                      :error -> "text-red-500 dark:text-red-400"
                    end
                }
                />
                <span class="text-sm font-medium">{message.text}</span>
              </div>
            </div>
          </div>
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
     |> assign_messages()
     |> stream(:recent_transactions, assigns.transactions |> Enum.take(5))}
  end

  @impl true
  def handle_event("select_chart_type", %{"chart_type" => chart_type}, socket) do
    transactions = socket.assigns.transactions
    categories = socket.assigns.categories
    monthly_income = socket.assigns.monthly_incomes || 0

    {:noreply,
     assign(socket,
       chart_type: String.to_existing_atom(chart_type),
       chart_option:
         categories
         |> format_categories(transactions, monthly_income)
         |> get_chart_data(String.to_existing_atom(chart_type)),
       form_chart: to_form(%{"chart_type" => chart_type})
     )
     |> stream(:recent_transactions, socket.assigns.transactions |> Enum.take(5))}
  end

  defp assign_balance(socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger
    profile_id = socket.assigns.profile_id

    new_balance = Balance.get_balance(current_scope, ledger.id, :all, profile_id)
    new_month_balance = Balance.get_balance(current_scope, ledger.id, :monthly, profile_id)

    assign(socket,
      balance: new_balance,
      month_balance: new_month_balance,
      monthly_incomes: new_month_balance.total_incomes
    )
  end

  defp assign_chart_data(socket) do
    chart_type = socket.assigns.chart_type || :bars
    categories = socket.assigns.categories || []
    transactions = socket.assigns.transactions || []
    monthly_income = socket.assigns.monthly_incomes || 0

    chart_data =
      categories
      |> format_categories(transactions, monthly_income)
      |> get_chart_data(chart_type)

    assign(socket, chart_option: chart_data)
  end

  defp assign_messages(socket) do
    formatted_categories =
      socket.assigns.categories
      |> format_categories(
        socket.assigns.transactions || [],
        socket.assigns.monthly_incomes || 0
      )

    investment_category =
      Enum.find(formatted_categories, fn category ->
        category.name == "Investimento"
      end)

    investment_message =
      if investment_category && investment_category.goal > 0 do
        if investment_category.remaining > 0 do
          %{
            text:
              "Você ainda tem R$ #{CurrencyUtils.format_amount(investment_category.remaining)} para investir este mês.",
            type: :info
          }
        else
          %{
            text: "Você atingiu sua meta de investimento para este mês!",
            type: :info
          }
        end
      else
        nil
      end

    messages = [investment_message]

    categories_messages =
      Enum.map(formatted_categories, fn category ->
        if category.name != "Sem Categoria" do
          percent_pass =
            if category.goal > 0 do
              Float.round(category.total / category.goal * 100, 2)
            else
              0.0
            end

          case percent_pass do
            percent when percent > 100 ->
              %{
                text:
                  "Você ultrapassou sua meta de #{category.name} em R$ #{CurrencyUtils.format_amount(abs(category.remaining))} (#{percent_pass}% da meta).",
                type: if(percent > 115, do: :error, else: :warning)
              }

            percent when percent > 85 ->
              %{
                text:
                  "Você está próximo de ultrapassar sua meta de #{category.name} (#{percent_pass}%). Faltam apenas R$ #{CurrencyUtils.format_amount(category.remaining)}.",
                type: :warning
              }

            _ ->
              nil
          end
        end
      end)

    messages =
      messages
      |> Enum.reject(&is_nil/1)
      |> Enum.concat(categories_messages)
      |> Enum.reject(&is_nil/1)

    IO.inspect(messages)

    assign(socket, messages: messages)
  end

  defp format_categories(categories, transactions, monthly_income) do
    categories
    |> Enum.sort()
    |> Enum.reject(fn category ->
      category.name == "Sem Categoria"
    end)
    |> Enum.map(fn category ->
      total =
        Enum.reduce(transactions, 0.0, fn t, acc ->
          if t.category_id == category.id, do: acc + t.total_value, else: acc
        end)

      total = Float.round(total, 2)
      goal = Float.round(category.percentage * monthly_income / 100, 2)

      remaining =
        if(category.name == "Sem Categoria",
          do: 0.0,
          else: Float.round(goal - total, 2)
        )

      %{
        id: category.id,
        name: category.name,
        color: category.color,
        percentage: category.percentage,
        total: total,
        goal: goal,
        remaining: remaining
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
                  color: category.color
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
            formatter: "R$ {value}",
            color: "#000",
            fontSize: 12,
            width: 100
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
