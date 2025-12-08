defmodule PersonalFinanceWeb.HomeLive.LedgerSummaryComponent do
  alias PersonalFinance.Investment
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Utils.CurrencyUtils
  alias PersonalFinance.Balance
  alias PersonalFinance.Goals
  import PersonalFinanceWeb.Components.CategoryPieChart

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <div class="rounded-2xl border border-base-200 bg-base-100/80 p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
            {gettext("Current Balance")}
          </p>
          <p class="text-3xl font-semibold text-base-content mt-2">
            {CurrencyUtils.format_money(@balance.balance)}
          </p>
          <p class="text-xs text-base-content/60 mt-1">{@ledger.name}</p>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-100/80 p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-wide text-success">
            {gettext("Incomes")}
          </p>
          <p class="text-2xl font-semibold text-base-content mt-2">
            + {CurrencyUtils.format_money(@month_balance.total_incomes_all_categories)}
          </p>
          <p class="text-xs text-base-content/60 mt-1">{gettext("Current month")}</p>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-100/80 p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-wide text-error">
            {gettext("Expenses")}
          </p>
          <p class="text-2xl font-semibold text-base-content mt-2">
            - {CurrencyUtils.format_money(@month_balance.total_expenses)}
          </p>
          <p class="text-xs text-base-content/60 mt-1">{gettext("Current month")}</p>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-100/80 p-5 shadow-sm">
          <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
            {gettext("Monthly Balance")}
          </p>
          <p class={[
            "text-2xl font-semibold mt-2",
            if(@month_balance.balance < 0, do: "text-error", else: "text-success")
          ]}>
            {CurrencyUtils.format_money(@month_balance.balance)}
          </p>
          <p class="text-xs text-base-content/60 mt-1">{gettext("Total")}</p>
        </div>
      </section>

      <section class="grid gap-6 lg:grid-cols-3">
        <div class="lg:col-span-2 rounded-2xl border border-base-200 bg-base-100/80 shadow-sm">
          <div class="flex flex-col gap-3 border-b border-base-200/70 p-5 md:flex-row md:items-center md:justify-between">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
                {gettext("Monthly Analysis")}
              </p>
              <p class="text-sm text-base-content/70">
                {gettext("See how categories perform this month.")}
              </p>
            </div>
            <.form
              id="chart_select_form"
              for={@form_chart}
              phx-change="select_chart_type"
              phx-target={@myself}
              class="w-full md:w-48 mr-3"
            >
              <.input
                type="select"
                field={@form_chart[:chart_type]}
                options={[{gettext("Bars"), :bars}, {gettext("Pie"), :pie}]}
                option_icons={%{
                  bars: "hero-chart-bar",
                  pie: "hero-chart-pie"
                }}
              />
            </.form>
          </div>
          <div class="p-5">
            <%= if @chart_type == :pie do %>
              <.category_pie_chart
                id="dashboard-pie"
                title={gettext("Expenses by category")}
                categories={@formatted_categories || []}
                empty_message={gettext("No expense data")}
                class="border-0"
              />
            <% else %>
              <div class="rounded-2xl border border-base-100 bg-base-100/80 p-6 shadow-sm">
                <h3 class="text-lg font-semibold text-base-content mb-4">
                  {gettext("Category Budget Tracking")}
                </h3>
                <div class="rounded-xl bg-base-200/60 p-4">
                  <div id="bar" phx-hook="Chart" class="h-80 w-full">
                    <div id="bar-chart" class="w-full h-80" phx-update="ignore" />
                    <div id="bar-data" hidden>{Jason.encode!(@chart_option)}</div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-100/80 shadow-sm flex flex-col">
          <div class="flex items-center justify-between border-b border-base-200/70 p-5">
            <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
              {gettext("Recent Transactions")}
            </p>
            <.link
              class="text-xs font-medium text-primary hover:underline"
              navigate={~p"/ledgers/#{@ledger.id}/transactions"}
            >
              {gettext("See all")}
            </.link>
          </div>

          <div class="p-5 space-y-3 flex-1">
            <%= if Enum.empty?(@recent_transactions) do %>
              <div class="rounded-xl border border-dashed border-base-300 p-6 text-center text-sm text-base-content/60">
                {gettext("No recent transactions yet.")}
              </div>
            <% else %>
              <div class="space-y-3">
                <div
                  :for={transaction <- @recent_transactions}
                  id={"recent-#{transaction.id}"}
                  class="flex items-center justify-between rounded-xl border border-base-200 bg-base-200/80 p-3"
                >
                  <div class="flex items-center gap-3 min-w-0">
                    <div class={[
                      "w-10 h-10 rounded-full flex items-center justify-center",
                      if(transaction.type == :expense,
                        do: "bg-error/10 text-error",
                        else: "bg-success/10 text-success"
                      )
                    ]}>
                      <.icon name="hero-banknotes" class="w-5 h-5" />
                    </div>
                    <div class="min-w-0">
                      <p class="text-sm font-medium text-base-content">
                        <.text_ellipsis text={transaction.description} max_width="max-w-[10rem]" />
                      </p>
                      <p class="text-xs text-base-content/60">
                        {DateUtils.format_date(transaction.date)} • {transaction.profile.name}
                      </p>
                    </div>
                  </div>
                  <p class={[
                    "text-sm font-semibold",
                    if(transaction.type == :expense, do: "text-error", else: "text-success")
                  ]}>
                    {CurrencyUtils.format_money(transaction.total_value)}
                  </p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>

      <%= if !Enum.empty?(@priority_goals) do %>
        <section class="rounded-2xl border border-base-200 bg-base-100/80 shadow-sm p-5">
          <div class="flex items-center justify-between mb-4">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
                {gettext("Goals")}
              </p>
              <p class="text-sm text-base-content/70">
                {gettext("Track your savings.")}
              </p>
            </div>
            <.link
              class="text-xs font-medium text-primary hover:underline"
              navigate={~p"/ledgers/#{@ledger.id}/goals"}
            >
              {gettext("See all")}
            </.link>
          </div>

          <div class="flex gap-4 overflow-x-auto pb-2">
            <div
              :for={goal <- @priority_goals}
              class="flex-shrink-0 w-80 rounded-xl border border-base-200 bg-base-200/50 p-4"
            >
              <div class="flex items-center justify-between mb-3">
                <div class="flex items-center gap-2">
                  <div
                    class="w-3 h-3 rounded-full"
                    style={"background-color: #{goal.color}"}
                  />
                  <h4 class="text-sm font-semibold text-base-content">
                    <.text_ellipsis text={goal.name} max_width="max-w-[10rem]" />
                  </h4>
                </div>
              </div>

              <div class="space-y-2 mb-3">
                <div class="flex justify-between text-xs text-base-content/70">
                  <span>{gettext("Progress")}</span>
                  <span class="font-semibold">{goal.progress_percent}%</span>
                </div>
                <div class="w-full bg-base-300 rounded-full h-2">
                  <div
                    class="h-2 rounded-full transition-all duration-300"
                    style={"width: #{goal.progress_percent}%; background-color: #{goal.color}"}
                  />
                </div>
              </div>

              <div class="space-y-1.5">
                <div class="flex justify-between text-xs">
                  <span class="text-base-content/60">{gettext("Current")}</span>
                  <span class="font-medium text-base-content">
                    {CurrencyUtils.format_money(Decimal.to_float(goal.current_total))}
                  </span>
                </div>
                <div class="flex justify-between text-xs">
                  <span class="text-base-content/60">{gettext("Target")}</span>
                  <span class="font-medium text-base-content">
                    {CurrencyUtils.format_money(Decimal.to_float(goal.target_amount))}
                  </span>
                </div>
                <%= if goal.forecast_date do %>
                  <div class="flex justify-between text-xs">
                    <span class="text-base-content/60">{gettext("Forecast")}</span>
                    <span class={[
                      "font-medium",
                      if(goal.will_meet_goal, do: "text-success", else: "text-warning")
                    ]}>
                      {DateUtils.format_date(goal.forecast_date)}
                    </span>
                  </div>
                <% end %>
                <%= if goal.days_remaining do %>
                  <div class="flex justify-between text-xs">
                    <span class="text-base-content/60">{gettext("Days left")}</span>
                    <span class={[
                      "font-medium",
                      cond do
                        goal.days_remaining < 0 -> "text-error"
                        goal.days_remaining < 30 -> "text-warning"
                        true -> "text-base-content"
                      end
                    ]}>
                      {if goal.days_remaining < 0, do: "#{gettext("Overdue")} #{abs(goal.days_remaining)}d", else: "#{goal.days_remaining}d"}
                    </span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </section>
      <% end %>

      <section class="grid gap-6 lg:grid-cols-3">
        <div class="rounded-2xl border border-base-200 bg-base-100/80 shadow-sm p-5">
          <div class="flex items-center justify-between mb-4">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
                {gettext("Fixed Income")}
              </p>
              <p class="text-sm text-base-content/70">
                {gettext("Track private investments at a glance.")}
              </p>
            </div>
            <.link
              class="text-xs font-medium text-primary hover:underline"
              navigate={~p"/ledgers/#{@ledger.id}/fixed_income"}
            >
              {gettext("See all")}
            </.link>
          </div>

          <div class="grid gap-3 sm:grid-cols-2">
            <div class="rounded-xl border border-base-200 p-3">
              <p class="text-xs text-base-content/60">{gettext("Total Invested")}</p>
              <p class="text-lg font-semibold text-base-content mt-1">
                {CurrencyUtils.format_money(@total_invested)}
              </p>
            </div>
            <div class="rounded-xl border border-base-200 p-3">
              <p class="text-xs text-base-content/60">{gettext("Current Value")}</p>
              <p class="text-lg font-semibold text-success mt-1">
                {CurrencyUtils.format_money(@current_value)}
              </p>
            </div>
          </div>

          <div class="grid gap-3 mt-4 sm:grid-cols-2">
            <div class="rounded-xl border border-base-200 p-3">
              <h4 class="text-xs font-semibold uppercase tracking-wide text-base-content/60 mb-2">
                {gettext("Fixed Income Composition")}
              </h4>
              <div id="fixed-income-composition-chart" class="w-full h-[120px]" phx-update="ignore" />
              <div id="fixed-income-composition-data" hidden>
                {Jason.encode!(%{"mock" => "data"})}
              </div>
            </div>
            <div class="rounded-xl border border-base-200 p-3">
              <h4 class="text-xs font-semibold uppercase tracking-wide text-base-content/60 mb-2">
                {gettext("Equity")}
              </h4>
              <div id="patrimony-chart" class="w-full h-[120px]" phx-update="ignore" />
              <div id="patrimony-data" hidden>{Jason.encode!(%{"mock" => "data"})}</div>
            </div>
          </div>
        </div>

        <%= if !Enum.empty?(@messages) do %>
          <div class="lg:col-span-2 rounded-2xl border border-base-200 bg-base-100/80 shadow-sm p-5">
            <div class="flex items-center gap-2 mb-4">
              <div class="w-8 h-8 rounded-full bg-amber-100 text-amber-900 dark:bg-amber-900/30 dark:text-amber-100 flex items-center justify-center">
                <.icon name="hero-bell" class="w-4 h-4" />
              </div>
              <div>
                <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
                  {gettext("Warnings")}
                </p>
                <p class="text-sm text-base-content/70">
                  {gettext("Keep an eye on budgets getting close to the limit.")}
                </p>
              </div>
            </div>

            <div class="space-y-3">
              <div
                :for={message <- @messages}
                class="flex items-start gap-3 rounded-xl border border-base-200 p-3"
              >
                <div class={[
                  "w-8 h-8 rounded-full flex items-center justify-center",
                  case message.type do
                    :info -> "bg-blue-100 text-blue-900 dark:bg-blue-900/30 dark:text-blue-100"
                    :warning -> "bg-yellow-100 text-yellow-900 dark:bg-yellow-900/30 dark:text-yellow-100"
                    :error -> "bg-red-100 text-red-900 dark:bg-red-900/30 dark:text-red-100"
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
                    class="w-4 h-4"
                  />
                </div>
                <p class="text-sm text-base-content/80 leading-relaxed">{message.text}</p>
              </div>
            </div>
          </div>
        <% end %>
      </section>
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
       form_chart: to_form(%{"chart_type" => chart_type}),
       recent_transactions: [],
       priority_goals: []
     )}
  end

  @impl true
  def update(assigns, socket) do
    recent_transactions = assigns.transactions |> Enum.take(5)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:recent_transactions, recent_transactions)
     |> assign_balance()
     |> assign_investment_data()
     |> assign_goals_data()
     |> assign_chart_data()
     |> assign_messages()}
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

  defp assign_goals_data(socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger

    goals =
      Goals.list_goals(current_scope, ledger.id, preload: [:fixed_incomes, :profile])
      |> Enum.map(fn goal ->
        forecast = Goals.forecast(goal, ledger.id)

        current_total =
          goal.fixed_incomes
          |> Enum.map(&Decimal.from_float(&1.current_balance))
          |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)

        progress_percent =
          if Decimal.compare(goal.target_amount, Decimal.new("0")) == :gt do
            current_total
            |> Decimal.div(goal.target_amount)
            |> Decimal.mult(Decimal.new("100"))
            |> Decimal.round(1)
            |> Decimal.to_float()
            |> min(100.0)
          else
            0.0
          end

        days_remaining =
          case {forecast.forecast_date, goal.target_date} do
            {%Date{} = _f_date, %Date{} = t_date} -> Date.diff(t_date, Date.utc_today())
            _ -> nil
          end

        will_meet_goal =
          case {forecast.forecast_date, goal.target_date} do
            {%Date{} = f_date, %Date{} = t_date} -> Date.compare(f_date, t_date) != :gt
            _ -> false
          end

        %{
          id: goal.id,
          name: goal.name,
          color: goal.color,
          target_amount: goal.target_amount,
          current_total: current_total,
          progress_percent: progress_percent,
          days_remaining: days_remaining,
          forecast_date: forecast.forecast_date,
          will_meet_goal: will_meet_goal
        }
      end)
      |> Enum.sort_by(fn g -> 100.0 - g.progress_percent end)

    assign(socket, priority_goals: goals)
  end

  defp assign_chart_data(socket) do
    chart_type = socket.assigns.chart_type || :bars
    categories = socket.assigns.categories || []
    transactions = socket.assigns.transactions || []
    monthly_income = socket.assigns.monthly_incomes || 0

    formatted_categories = format_categories(categories, transactions, monthly_income)

    chart_data = get_chart_data(formatted_categories, chart_type)

    socket
    |> assign(chart_option: chart_data)
    |> assign(formatted_categories: formatted_categories)
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

  defp get_chart_data(categories_data, :bars) do
    remaining_label = gettext("Remaining")
    spent_label = gettext("Spent")
    goal_label = gettext("Goal")

    truncated_names = Enum.map(categories_data, &truncate_text(&1.name, 20))

    remaining_values =
      Enum.map(categories_data, fn item ->
        if item.remaining < 0 do
          %{
            value: item.remaining,
            itemStyle: %{color: "#ef4444"}
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
        borderColor: "#e5e7eb",
        borderWidth: 1,
        borderRadius: 8,
        padding: 12,
        textStyle: %{
          color: "#374151",
          fontSize: 13,
          fontFamily: "system-ui, -apple-system, sans-serif"
        },
        formatter:
          "{b0}<br/><span style='display:inline-block;margin-right:4px;border-radius:10px;width:10px;height:10px;background-color:#9ca3af;'></span> #{goal_label}: R${c2}<br/><span style='display:inline-block;margin-right:4px;border-radius:10px;width:10px;height:10px;background-color:#f59e0b;'></span> #{spent_label}: R${c1}<br/><span style='display:inline-block;margin-right:4px;border-radius:10px;width:10px;height:10px;background-color:#10b981;'></span> #{remaining_label}: R${c0}"
      },
      legend: %{
        top: 5,
        left: "center",
        data: [remaining_label, spent_label, goal_label],
        textStyle: %{
          color: "#6b7280",
          fontSize: 13,
          fontWeight: "500",
          fontFamily: "system-ui, -apple-system, sans-serif"
        },
        itemGap: 24,
        itemWidth: 14,
        itemHeight: 14,
        icon: "roundRect"
      },
      grid: %{
        left: "3%",
        right: "8%",
        top: "15%",
        bottom: "5%",
        containLabel: true
      },
      xAxis: [
        %{
          type: "value",
          axisLabel: %{
            formatter: "R$ {value}",
            color: "#9ca3af",
            fontSize: 11,
            fontFamily: "system-ui, -apple-system, sans-serif"
          },
          axisLine: %{
            show: false
          },
          splitLine: %{
            show: true,
            lineStyle: %{
              color: "#f3f4f6",
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
            color: "#4b5563",
            fontSize: 13,
            fontWeight: "500",
            interval: 0,
            margin: 10,
            fontFamily: "system-ui, -apple-system, sans-serif"
          },
          axisLine: %{
            show: false
          },
          splitLine: %{
            show: false
          }
        }
      ],
      series: [
        %{
          name: remaining_label,
          meta_key: "remaining",
          type: "bar",
          stack: "total_sum",
          barWidth: "55%",
          itemStyle: %{
            color: "#10b981",
            borderRadius: [0, 4, 4, 0]
          },
          label: %{
            show: true,
            position: "insideRight",
            formatter: "R${c}",
            color: "#fff",
            fontSize: 11,
            fontWeight: "600",
            fontFamily: "system-ui, -apple-system, sans-serif"
          },
          emphasis: %{
            focus: "series",
            itemStyle: %{
              color: "#059669",
              shadowBlur: 10,
              shadowColor: "rgba(16, 185, 129, 0.3)"
            }
          },
          data: remaining_values
        },
        %{
          name: spent_label,
          meta_key: "spent",
          type: "bar",
          stack: "total_sum",
          itemStyle: %{
            color: "#f59e0b",
            borderRadius: [4, 0, 0, 4]
          },
          label: %{
            show: true,
            position: "insideLeft",
            formatter: "R${c}",
            color: "#fff",
            fontSize: 11,
            fontWeight: "600",
            fontFamily: "system-ui, -apple-system, sans-serif"
          },
          emphasis: %{
            focus: "series",
            itemStyle: %{
              color: "#d97706",
              shadowBlur: 10,
              shadowColor: "rgba(245, 158, 11, 0.3)"
            }
          },
          data: total_values
        },
        %{
          name: goal_label,
          meta_key: "goal",
          type: "bar",
          barWidth: "40%",
          itemStyle: %{
            color: "#9ca3af",
            borderRadius: 4
          },
          label: %{
            show: true,
            position: "right",
            formatter: "R${c}",
            fontSize: 11,
            color: "#6b7280",
            fontWeight: "500",
            fontFamily: "system-ui, -apple-system, sans-serif",
            offset: [5, 0]
          },
          emphasis: %{
            focus: "series",
            itemStyle: %{
              color: "#6b7280",
              shadowBlur: 8,
              shadowColor: "rgba(156, 163, 175, 0.3)"
            }
          },
          z: -1,
          data: goal_values
        }
      ]
    }
  end

    defp get_chart_data(_categories_data, _type) do
      %{ }
    end
end
