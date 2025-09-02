defmodule PersonalFinanceWeb.HomeLive.LedgerSummaryComponent do
  alias PersonalFinance.Investment
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Utils.CurrencyUtils
  alias PersonalFinance.Balance

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col xl:grid xl:grid-cols-4 gap-6 px-4">
      <div class="w-full xl:col-span-1 flex flex-col gap-6">
        <div class="bg-gradient-to-br from-base-300 to-base-200 rounded-2xl p-4 shadow-lg border border-base-200/50 backdrop-blur-sm">
          <div class="space-y-4">
            <div class="relative">
              <div class="absolute -inset-1 bg-gradient-to-r from-blue-600/20 to-purple-600/20 rounded-xl blur opacity-30">
              </div>
              <div class="relative bg-white/50 dark:bg-black/20 rounded-xl p-2 border border-white/20">
                <h3 class="text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Saldo Atual</h3>
                <span class="text-xl font-black bg-gradient-to-r from-gray-900 to-gray-600 dark:from-white dark:to-gray-300 bg-clip-text text-transparent">
                  {@balance.balance |> CurrencyUtils.format_money()}
                </span>
              </div>
            </div>

            <div>
              <h3 class="text-xs font-medium text-gray-600 dark:text-gray-400 mb-2">Saldo Mensal</h3>
              <div class="space-y-2">
                <div class="flex justify-between items-center py-2 px-3 bg-green-50 dark:bg-green-900/20 rounded-lg">
                  <span class="text-xs font-medium text-green-700 dark:text-green-300">Receitas</span>
                  <span class="text-sm font-bold text-green-600 dark:text-green-400">
                    + {@month_balance.total_incomes |> CurrencyUtils.format_money()}
                  </span>
                </div>
                <div class="flex justify-between items-center py-2 px-3 bg-red-50 dark:bg-red-900/20 rounded-lg">
                  <span class="text-xs font-medium text-red-700 dark:text-red-300">Despesas</span>
                  <span class="text-sm font-bold text-red-600 dark:text-red-400">
                    - {@month_balance.total_expenses |> CurrencyUtils.format_money()}
                  </span>
                </div>
                <div class="pt-2 border-t border-gray-200 dark:border-gray-700">
                  <div class="flex justify-between items-center">
                    <span class="text-xs font-medium text-gray-600 dark:text-gray-400">Total</span>
                    <span class={[
                      "text-lg font-black",
                      if(@month_balance.balance < 0,
                        do: "text-red-600 dark:text-red-400",
                        else: "text-green-600 dark:text-green-400"
                      )
                    ]}>
                      {@month_balance.balance |> CurrencyUtils.format_money()}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-gradient-to-br from-base-300 to-base-200 rounded-2xl shadow-lg border border-base-200/50 backdrop-blur-sm flex-1">
          <div class="p-4 pb-2 border-b border-base-200/50">
            <div class="flex justify-between items-center">
              <h3 class="text-lg font-bold text-gray-800 dark:text-white">Transações Recentes</h3>
              <.link
                class="text-xs font-medium text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 transition-colors flex items-center w-full justify-end hover:gap-2 duration-200"
                navigate={~p"/ledgers/#{@ledger.id}/transactions"}
              >
                Ver todas <.icon name="hero-arrow-right" class="w-3 h-3" />
              </.link>
            </div>
          </div>

          <div class="divide-y divide-base-200/30">
            <div
              :for={{id, transaction} <- @streams.recent_transactions}
              class="flex items-center justify-between p-4 hover:bg-white/30 dark:hover:bg-black/20 transition-all duration-200 group cursor-pointer"
              id={id}
            >
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-gradient-to-br from-blue-500/20 to-purple-500/20 flex items-center justify-center group-hover:from-blue-500/30 group-hover:to-purple-500/30 transition-all">
                  <.icon name="hero-banknotes" class="w-5 h-5 text-blue-600 dark:text-blue-400" />
                </div>
                <div class="min-w-0 flex-1">
                  <.text_ellipsis
                    text={transaction.description}
                    max_width="max-w-[100px] sm:max-w-[200px] lg:max-w-[100px]"
                    class="text-sm font-semibold text-gray-900 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors"
                  />
                  <.text_ellipsis
                    text={transaction.profile.name}
                    max_width="max-w-[100px] sm:max-w-[200px] lg:max-w-[100px]"
                    class="text-xs text-gray-500 dark:text-gray-400"
                  />
                </div>
              </div>
              <div class="text-right">
                <div class={"text-sm font-bold text-gray-900 dark:text-white #{if transaction.type == :expense, do: "text-red-600 dark:text-red-400", else: "text-green-600 dark:text-green-400"}"}>
                  {CurrencyUtils.format_money(transaction.total_value)}
                </div>
                <div class="text-xs text-gray-500 dark:text-gray-400">
                  {DateUtils.format_date(transaction.date)}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="w-full xl:col-span-2 flex flex-col gap-6">
        <div class="bg-gradient-to-br from-base-300 to-base-200 rounded-2xl shadow-xl border border-base-200/50 backdrop-blur-sm flex-1 max-h-fit">
          <div class="p-4 pb-2 border-b border-base-200/30">
            <div class="flex justify-between items-center">
              <h3 class="text-lg font-bold bg-gradient-to-r from-gray-800 to-gray-600 dark:from-white dark:to-gray-300 bg-clip-text text-transparent">
                Análise Mensal
              </h3>
              <.form
                id="chart_select_form"
                for={@form_chart}
                phx-change="select_chart_type"
                phx-target={@myself}
                class="relative"
              >
                <.input
                  type="select"
                  field={@form_chart[:chart_type]}
                  options={[{"Barras", :bars}, {"Pizza", :pie}]}
                  class="bg-white/50 dark:bg-black/20 border-white/30 dark:border-white/10 rounded-xl text-xs font-medium focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500/50 transition-all"
                />
              </.form>
            </div>
          </div>

          <div class="p-4">
            <div class="relative bg-white/30 dark:bg-black/10 rounded-2xl p-4 min-h-[300px] backdrop-blur-sm border border-white/20">
              <%= if @chart_type == :pie do %>
                <div id="pie" phx-hook="Chart" class="h-full">
                  <div id="pie-chart" class="w-full h-[300px]" phx-update="ignore" />
                  <div id="pie-data" hidden>{Jason.encode!(@chart_option)}</div>
                </div>
              <% else %>
                <%= if @chart_type == :bars do %>
                  <div id="bar" phx-hook="Chart" class="h-full">
                    <div
                      id="bar-chart"
                      class="w-full h-[300px]"
                      phx-update="ignore"
                      style="overflow: visible;"
                    />
                    <div id="bar-data" hidden>{Jason.encode!(@chart_option)}</div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <%= if !Enum.empty?(@messages) do %>
          <div class="bg-gradient-to-br from-base-300 to-base-200 rounded-2xl p-4 shadow-lg border border-base-200/50 backdrop-blur-sm">
            <div class="flex items-center gap-2 mb-2">
              <div class="w-6 h-6 rounded-full bg-gradient-to-br from-amber-500/20 to-orange-500/20 flex items-center justify-center">
                <.icon name="hero-bell" class="w-4 h-4 text-amber-600 dark:text-amber-400" />
              </div>
              <h3 class="text-sm font-bold text-gray-800 dark:text-white">Avisos</h3>
            </div>

            <div class="space-y-2">
              <div
                :for={message <- @messages}
                class="flex items-start gap-2 bg-white/40 dark:bg-black/20 rounded-xl p-3 hover:bg-white/60 dark:hover:bg-black/30 transition-all duration-200 border border-white/20 group"
              >
                <div class={[
                  "w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0",
                  case message.type do
                    :info -> "bg-blue-500/20 group-hover:bg-blue-500/30"
                    :warning -> "bg-yellow-500/20 group-hover:bg-yellow-500/30"
                    :error -> "bg-red-500/20 group-hover:bg-red-500/30"
                  end
                ]}>
                  <.icon
                    name={
                      case message.type do
                        :info -> "hero-information-circle"
                        :warning -> "hero-exclamation-triangle"
                        :error -> "hero-x-circle"
                      end
                    }
                    class={[
                      "w-3 h-3",
                      case message.type do
                        :info -> "text-blue-600 dark:text-blue-400"
                        :warning -> "text-yellow-600 dark:text-yellow-400"
                        :error -> "text-red-600 dark:text-red-400"
                      end
                    ]}
                  />
                </div>
                <span class="text-xs font-medium text-gray-700 dark:text-gray-300 leading-relaxed">
                  {message.text}
                </span>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <div class="w-full xl:col-span-1 flex flex-col gap-6">
        <div class="bg-gradient-to-br from-base-300 to-base-200 rounded-2xl shadow-lg border border-base-200/50 backdrop-blur-sm flex-1 max-h-fit">
          <div class="p-4 pb-2 border-b border-base-200/50">
            <div class="flex justify-between items-center">
              <h3 class="text-lg font-bold bg-gradient-to-r from-gray-800 to-gray-600 dark:from-white dark:to-gray-300 bg-clip-text text-transparent">
                Renda Fixa
              </h3>
              <.link
                class="text-xs font-medium text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 transition-colors flex items-center justify-end hover:gap-2 duration-200"
                navigate={~p"/ledgers/#{@ledger.id}/fixed_income"}
              >
                Ver todos <.icon name="hero-arrow-right" class="w-3 h-3" />
              </.link>
            </div>
          </div>

          <div class="p-4 space-y-4">
            <div class="space-y-2">
              <div class="flex justify-between items-center">
                <span class="text-xs font-medium text-gray-600 dark:text-gray-400">
                  Total Investido
                </span>
                <span class="text-sm font-bold text-gray-900 dark:text-white">
                  {CurrencyUtils.format_money(@total_invested)}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-xs font-medium text-gray-600 dark:text-gray-400">
                  Valor Atual
                </span>
                <span class="text-sm font-bold text-green-600 dark:text-green-400">
                  {CurrencyUtils.format_money(@current_value)}
                </span>
              </div>
            </div>

            <div class="space-y-2">
              <div class="relative bg-white/30 dark:bg-black/10 rounded-xl p-2 min-h-[150px] backdrop-blur-sm border border-white/20">
                <h4 class="text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
                  Composição da Renda Fixa
                </h4>
                <div id="fixed-income-composition-chart" class="w-full h-[120px]" phx-update="ignore" />
                <div id="fixed-income-composition-data" hidden>
                  {Jason.encode!(%{"mock" => "data"})}
                </div>
              </div>
              <div class="relative bg-white/30 dark:bg-black/10 rounded-xl p-2 min-h-[150px] backdrop-blur-sm border border-white/20">
                <h4 class="text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Patrimônio</h4>
                <div id="patrimony-chart" class="w-full h-[120px]" phx-update="ignore" />
                <div id="patrimony-data" hidden>{Jason.encode!(%{"mock" => "data"})}</div>
              </div>
            </div>
          </div>
        </div>
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
     |> assign_investment_data()
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

  defp assign_investment_data(socket) do
    ledger = socket.assigns.ledger

    investment_data = Investment.get_total_invested(ledger.id)

    assign(socket,
      total_invested: investment_data.total_invested,
      current_value: investment_data.total_balance
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

    assign(socket, messages: messages)
  end

  defp format_categories(categories, transactions, monthly_income) do
    month_start = Date.beginning_of_month(Date.utc_today())

    categories
    |> Enum.sort()
    |> Enum.reject(&(&1.name == "Sem Categoria"))
    |> Enum.map(fn category ->
      {total_expenses, total_incomes} =
        Enum.reduce(transactions, {0.0, 0.0}, fn t, {exp_acc, inc_acc} ->
          if Date.compare(t.date, month_start) != :lt do
            if t.category_id == category.id do
              case t.type do
                :expense -> {exp_acc + t.total_value, inc_acc}
                :income -> {exp_acc, inc_acc + t.total_value}
                _ -> {exp_acc, inc_acc}
              end
            else
              {exp_acc, inc_acc}
            end
          else
            {exp_acc, inc_acc}
          end
        end)

      goal = Float.round(category.percentage * monthly_income / 100, 2) + total_incomes
      remaining = Float.round(goal - total_expenses, 2)

      %{
        id: category.id,
        name: category.name,
        color: category.color,
        percentage: category.percentage,
        total: Float.round(total_expenses, 2),
        total_incomes: Float.round(total_incomes, 2),
        goal: goal,
        remaining: remaining
      }
    end)
  end

  defp truncate_text(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length - 3) <> "..."
    else
      text
    end
  end

  defp get_chart_data(categories_data, :pie) do
    option = %{
      tooltip: %{
        trigger: "item",
        formatter: "{b}: {c} ({d}%)"
      },
      legend: %{
        top: "0",
        left: "left",
        textStyle: %{
          color: "#000",
          fontSize: 18
        },
        formatter: "{name}"
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
                name: truncate_text(category.name, 12),
                value: category.total,
                originalName: category.name,
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
    truncated_names = Enum.map(categories_data, &truncate_text(&1.name, 20))

    remaining_values =
      Enum.map(categories_data, fn item ->
        if item.remaining < 0 do
          %{
            value: item.remaining,
            itemStyle: %{color: "#F44336"}
          }
        else
          item.remaining
        end
      end)

    total_values = Enum.map(categories_data, & &1.total)
    goal_values = Enum.map(categories_data, & &1.goal)

    %{
      tooltip: %{
        trigger: "axis",
        axisPointer: %{
          type: "shadow"
        },
        backgroundColor: "rgba(255, 255, 255, 0.95)",
        borderColor: "#ccc",
        borderWidth: 1,
        textStyle: %{
          color: "#333",
          fontSize: 13
        },
        formatter:
          "{b0}<br/><span style='color:#9E9E9E'>●</span> Meta: R${c2}<br/><span style='color:#FF9800'>●</span> Gasto: R${c1}<br/><span style='color:#4CAF50'>●</span> Restante: R${c0}"
      },
      legend: %{
        top: 10,
        left: "center",
        data: ["Restante", "Gasto", "Meta"],
        textStyle: %{
          color: "#333",
          fontSize: 14,
          fontWeight: "500"
        },
        itemGap: 30,
        icon: "roundRect"
      },
      grid: %{
        left: "5%",
        right: "12%",
        top: "15%",
        bottom: "8%",
        containLabel: true
      },
      xAxis: [
        %{
          type: "value",
          axisLabel: %{
            formatter: "R$ {value}",
            color: "#666",
            fontSize: 11,
            fontFamily: "Arial, sans-serif"
          },
          axisLine: %{
            show: true,
            lineStyle: %{
              color: "#ddd"
            }
          },
          splitLine: %{
            show: true,
            lineStyle: %{
              color: "#f0f0f0",
              type: "solid",
              width: 1
            }
          },
          axisTick: %{
            show: false
          }
        }
      ],
      yAxis: [
        %{
          type: "category",
          axisTick: %{
            show: false
          },
          data: truncated_names,
          axisLabel: %{
            color: "#333",
            fontSize: 13,
            fontWeight: "500",
            interval: 0,
            margin: 12,
            fontFamily: "Arial, sans-serif"
          },
          axisLine: %{
            show: true,
            lineStyle: %{
              color: "#ddd"
            }
          },
          splitLine: %{
            show: false
          }
        }
      ],
      series: [
        %{
          name: "Restante",
          type: "bar",
          stack: "total_sum",
          barWidth: "50%",
          itemStyle: %{
            color: "#4CAF50",
            borderRadius: [3, 3, 3, 3]
          },
          label: %{
            show: true,
            position: "insideRight",
            formatter: "R${c}",
            color: "#fff",
            fontSize: 12,
            fontWeight: "600",
            textShadowBlur: 2,
            textShadowColor: "rgba(0, 0, 0, 0.3)"
          },
          emphasis: %{
            focus: "series",
            itemStyle: %{
              color: "#45a049"
            }
          },
          data: remaining_values
        },
        %{
          name: "Gasto",
          type: "bar",
          stack: "total_sum",
          itemStyle: %{
            color: "#FF9800",
            borderRadius: [3, 3, 3, 3]
          },
          label: %{
            show: true,
            position: "insideLeft",
            formatter: "R${c}",
            color: "#fff",
            fontSize: 12,
            fontWeight: "600",
            textShadowBlur: 2,
            textShadowColor: "rgba(0, 0, 0, 0.3)"
          },
          emphasis: %{
            focus: "series",
            itemStyle: %{
              color: "#f57c00"
            }
          },
          data: total_values
        },
        %{
          name: "Meta",
          type: "bar",
          barWidth: "35%",
          itemStyle: %{
            color: "#9E9E9E",
            borderColor: "#9E9E9E",
            borderRadius: 3
          },
          label: %{
            show: true,
            position: "right",
            formatter: "R${c}",
            fontSize: 11,
            color: "#666",
            fontWeight: "500",
            offset: [5, 0]
          },
          emphasis: %{
            focus: "series",
            itemStyle: %{
              borderColor: "#757575",
              borderWidth: 3
            }
          },
          z: -1,
          data: goal_values
        }
      ]
    }
  end
end
