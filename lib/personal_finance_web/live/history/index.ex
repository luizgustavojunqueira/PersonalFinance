defmodule PersonalFinanceWeb.HistoryLive.Index do
  use PersonalFinanceWeb, :live_view

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
      today = Date.utc_today()
      filters = default_filters()

      socket =
        socket
        |> assign(
          ledger: ledger,
          page_title: gettext("Historical Analysis"),
          filters: filters,
          view_mode: :overview,
          selected_year: today.year,
          selected_month: today.month
        )

      {:ok, load_history(socket)}
    end
  end

  @impl true
  def handle_event("filter", %{"filters" => filters_params}, socket) do
    filters = normalize_filters(filters_params, socket.assigns.filters)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> load_history()}
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    view_mode = String.to_existing_atom(mode)
    {:noreply, assign(socket, view_mode: view_mode)}
  end

  @impl true
  def handle_event("prev_month", _, socket) do
    {year, month} = shift_month(socket.assigns.selected_year, socket.assigns.selected_month, -1)

    {:noreply,
     socket
     |> assign(selected_year: year, selected_month: month)
     |> load_month_detail()}
  end

  @impl true
  def handle_event("next_month", _, socket) do
    {year, month} = shift_month(socket.assigns.selected_year, socket.assigns.selected_month, 1)

    {:noreply,
     socket
     |> assign(selected_year: year, selected_month: month)
     |> load_month_detail()}
  end

  defp load_history(socket) do
    filters = socket.assigns.filters

    monthly =
      Finance.history_monthly_summary(
        socket.assigns.current_scope,
        socket.assigns.ledger,
        filters
      )

    expense_categories =
      Finance.history_category_breakdown(
        socket.assigns.current_scope,
        socket.assigns.ledger,
        filters
      )

    income_categories =
      Finance.history_income_breakdown(
        socket.assigns.current_scope,
        socket.assigns.ledger,
        filters
      )

    fixed_income =
      Finance.history_fixed_income_flows(
        socket.assigns.current_scope,
        socket.assigns.ledger,
        filters
      )

    latest_month = List.last(monthly)
    prev_month = monthly |> Enum.drop(-1) |> List.last()

    expense_compare = build_category_compare(latest_month, prev_month, expense_categories)
    income_compare = build_category_compare(latest_month, prev_month, income_categories)
    fixed_income_cumulative = build_cumulative(fixed_income)

    monthly_chart = chart_monthly_option(monthly)
    expense_chart = chart_category_option(expense_compare, "expense")
    income_chart = chart_category_option(income_compare, "income")
    fixed_income_chart = chart_fixed_income_option(fixed_income_cumulative)

    socket
    |> assign(
      monthly: monthly,
      expense_compare: expense_compare,
      income_compare: income_compare,
      fixed_income: fixed_income_cumulative,
      monthly_chart: monthly_chart,
      expense_chart: expense_chart,
      income_chart: income_chart,
      fixed_income_chart: fixed_income_chart,
      latest_month: latest_month,
      prev_month: prev_month
    )
    |> load_month_detail()
  end

  defp load_month_detail(socket) do
    year = socket.assigns.selected_year
    month = socket.assigns.selected_month

    month_str = "#{year}-#{String.pad_leading("#{month}", 2, "0")}"
    month_filters = %{start_month: month_str, end_month: month_str}

    monthly_data =
      Finance.history_monthly_summary(
        socket.assigns.current_scope,
        socket.assigns.ledger,
        month_filters
      )

    expense_data =
      Finance.history_category_breakdown(
        socket.assigns.current_scope,
        socket.assigns.ledger,
        month_filters
      )

    income_data =
      Finance.history_income_breakdown(
        socket.assigns.current_scope,
        socket.assigns.ledger,
        month_filters
      )

    current_month = List.first(monthly_data)

    {prev_year, prev_month} = shift_month(year, month, -1)
    prev_month_str = "#{prev_year}-#{String.pad_leading("#{prev_month}", 2, "0")}"
    prev_filters = %{start_month: prev_month_str, end_month: prev_month_str}

    prev_monthly_data =
      Finance.history_monthly_summary(
        socket.assigns.current_scope,
        socket.assigns.ledger,
        prev_filters
      )

    previous_month = List.first(prev_monthly_data)

    month_expense_pie = chart_category_pie(expense_data)
    month_income_pie = chart_category_pie(income_data)

    socket
    |> assign(
      current_month_data: current_month,
      previous_month_data: previous_month,
      month_expense_data: expense_data,
      month_income_data: income_data,
      month_expense_pie: month_expense_pie,
      month_income_pie: month_income_pie
    )
  end

  defp normalize_filters(params, current_filters) do
    %{
      start_month: Map.get(params, "start_month") || current_filters.start_month,
      end_month: Map.get(params, "end_month") || current_filters.end_month
    }
  end

  defp default_filters do
    today = Date.utc_today()
    {start_year, start_month} = shift_month(today.year, today.month, -11)

    %{
      start_month: format_month_param(start_year, start_month),
      end_month: format_month_param(today.year, today.month)
    }
  end

  defp format_month_param(year, month) do
    :io_lib.format("~4..0B-~2..0B", [year, month]) |> IO.iodata_to_binary()
  end

  defp shift_month(year, month, delta) do
    total = year * 12 + month - 1 + delta
    new_year = div(total, 12)
    new_month = rem(total, 12) + 1
    {new_year, new_month}
  end

  defp build_category_compare(nil, _prev_month, _categories), do: []

  defp build_category_compare(latest_month, prev_month, categories) do
    latest_key = {latest_month.year, latest_month.month}
    prev_key = if prev_month, do: {prev_month.year, prev_month.month}, else: nil

    latest_map = category_totals_for(categories, latest_key)
    prev_map = if prev_key, do: category_totals_for(categories, prev_key), else: %{}

    latest_map
    |> Enum.map(fn {cat_id, %{name: name, color: color, total: total}} ->
      prev_total = prev_map |> Map.get(cat_id, %{total: 0}) |> Map.get(:total)
      delta = total - prev_total
      delta_pct = if prev_total == 0, do: nil, else: delta / prev_total * 100

      %{
        id: cat_id,
        name: name,
        color: color,
        total: total,
        prev_total: prev_total,
        delta: delta,
        delta_pct: delta_pct
      }
    end)
    |> Enum.sort_by(& &1.total, :desc)
  end

  defp category_totals_for(categories, key) do
    categories
    |> Enum.filter(fn row -> {row.year, row.month} == key end)
    |> Enum.reduce(%{}, fn row, acc ->
      Map.put(acc, row.category_id, %{
        name: row.category_name,
        color: row.category_color,
        total: row.total || 0
      })
    end)
  end

  defp build_cumulative(rows) do
    rows
    |> Enum.sort_by(fn r -> {r.year, r.month} end)
    |> Enum.map_reduce(0, fn row, acc ->
      cumulative = acc + row.net
      {Map.put(row, :cumulative, cumulative), cumulative}
    end)
    |> elem(0)
  end

  defp chart_monthly_option([]), do: %{}

  defp chart_monthly_option(rows) do
    labels = Enum.map(rows, &month_label/1)
    incomes = Enum.map(rows, &to_float(&1.income))
    expenses = Enum.map(rows, &(-to_float(&1.expense)))
    net = Enum.map(rows, &to_float(&1.net))
    closing = Enum.map(rows, &to_float(&1.closing_balance))

    %{
      tooltip: %{trigger: "axis"},
      legend: %{
        data: [gettext("Income"), gettext("Expenses"), gettext("Net"), gettext("Closing")],
        top: 0
      },
      grid: %{left: "4%", right: "4%", bottom: "6%", top: "15%", containLabel: true},
      xAxis: [%{type: "category", data: labels}],
      yAxis: [%{type: "value"}],
      series: [
        %{
          name: gettext("Income"),
          type: "bar",
          stack: "flow",
          emphasis: %{focus: "series"},
          data: incomes
        },
        %{
          name: gettext("Expenses"),
          type: "bar",
          stack: "flow",
          emphasis: %{focus: "series"},
          data: expenses
        },
        %{name: gettext("Net"), type: "line", smooth: true, data: net},
        %{name: gettext("Closing"), type: "line", smooth: true, data: closing}
      ]
    }
  end

  defp chart_category_option([], _type), do: %{}

  defp chart_category_option(rows, _type) do
    labels = Enum.map(rows, & &1.name)
    currents = Enum.map(rows, &to_float(&1.total))
    prevs = Enum.map(rows, &to_float(&1.prev_total))

    %{
      tooltip: %{trigger: "axis", axisPointer: %{type: "shadow"}},
      legend: %{data: [gettext("Current"), gettext("Previous")], top: 0},
      grid: %{left: "2%", right: "2%", bottom: "4%", top: "15%", containLabel: true},
      xAxis: %{type: "value"},
      yAxis: %{type: "category", data: labels},
      series: [
        %{name: gettext("Current"), type: "bar", barWidth: "40%", data: currents},
        %{name: gettext("Previous"), type: "bar", barWidth: "40%", data: prevs}
      ]
    }
  end

  defp chart_fixed_income_option([]), do: %{}

  defp chart_fixed_income_option(rows) do
    labels = Enum.map(rows, &month_label/1)
    inflows = Enum.map(rows, &to_float(&1.inflow))
    outflows = Enum.map(rows, &to_float(&1.outflow))
    net = Enum.map(rows, &to_float(&1.net))
    cumulative = Enum.map(rows, &to_float(&1.cumulative))

    %{
      tooltip: %{trigger: "axis"},
      legend: %{
        data: [gettext("Inflows"), gettext("Outflows"), gettext("Net"), gettext("Cumulative")],
        top: 0
      },
      grid: %{left: "4%", right: "4%", bottom: "6%", top: "15%", containLabel: true},
      xAxis: [%{type: "category", data: labels}],
      yAxis: [%{type: "value"}],
      series: [
        %{name: gettext("Inflows"), type: "line", smooth: true, areaStyle: %{}, data: inflows},
        %{name: gettext("Outflows"), type: "line", smooth: true, areaStyle: %{}, data: outflows},
        %{name: gettext("Net"), type: "line", smooth: true, data: net},
        %{name: gettext("Cumulative"), type: "line", smooth: true, data: cumulative}
      ]
    }
  end

  defp to_float(nil), do: 0.0
  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value * 1.0

  defp chart_category_pie([]), do: %{}

  defp chart_category_pie(categories) do
    data =
      Enum.map(categories, fn cat ->
        %{
          value: to_float(cat.total),
          name: cat.category_name,
          itemStyle: %{color: cat.category_color}
        }
      end)

    %{
      tooltip: %{trigger: "item", formatter: "{b}: {c} ({d}%)"},
      legend: %{
        orient: "vertical",
        left: "left",
        data: Enum.map(categories, & &1.category_name)
      },
      series: [
        %{
          type: "pie",
          radius: ["40%", "70%"],
          avoidLabelOverlap: false,
          itemStyle: %{
            borderRadius: 10,
            borderColor: "#fff",
            borderWidth: 2
          },
          label: %{
            show: true,
            formatter: "{b}: {d}%"
          },
          emphasis: %{
            label: %{
              show: true,
              fontSize: 16,
              fontWeight: "bold"
            }
          },
          data: data
        }
      ]
    }
  end

  defp month_label(%{year: y, month: m}) do
    :io_lib.format("~2..0B/~4..0B", [m, y]) |> IO.iodata_to_binary()
  end

  defp net_trend(_latest, nil), do: nil
  defp net_trend(latest, prev), do: latest.net - prev.net

  defp closing_trend(_latest, nil), do: nil
  defp closing_trend(latest, prev), do: latest.closing_balance - prev.closing_balance

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} show_sidebar={true} ledger={@ledger}>
      <div class="min-h-screen pb-12 space-y-6">
        <section class="bg-base-100/80 border border-base-300 rounded-2xl p-6 shadow-sm mt-4">
          <div class="flex flex-col gap-6">
            <div class="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
              <div class="space-y-3">
                <p class="text-sm font-semibold uppercase tracking-wide text-primary/70">
                  {gettext("Historical Analysis")}
                </p>
                <div class="space-y-1">
                  <h1 class="text-3xl font-bold text-base-content">{@ledger.name}</h1>
                  <p class="text-sm text-base-content/70">
                    {gettext("Monthly performance, categories and fixed income flows.")}
                  </p>
                </div>
              </div>

              <.form for={%{}} phx-change="filter" class="w-full lg:w-auto">
                <div class="flex flex-col gap-3 lg:flex-row lg:items-end">
                  <div class="flex flex-col gap-1">
                    <label class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                      {gettext("Start month")}
                    </label>
                    <input
                      type="month"
                      name="filters[start_month]"
                      value={@filters.start_month}
                      class="input input-bordered"
                    />
                  </div>
                  <div class="flex flex-col gap-1">
                    <label class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                      {gettext("End month")}
                    </label>
                    <input
                      type="month"
                      name="filters[end_month]"
                      value={@filters.end_month}
                      class="input input-bordered"
                    />
                  </div>
                </div>
              </.form>
            </div>

            <div class="flex gap-2">
              <button
                phx-click="switch_mode"
                phx-value-mode="overview"
                class={"btn btn-sm " <> if(@view_mode == :overview, do: "btn-primary", else: "btn-ghost")}
              >
                <.icon name="hero-chart-bar" class="w-4 h-4" />
                {gettext("Overview")}
              </button>
              <button
                phx-click="switch_mode"
                phx-value-mode="monthly"
                class={"btn btn-sm " <> if(@view_mode == :monthly, do: "btn-primary", else: "btn-ghost")}
              >
                <.icon name="hero-calendar" class="w-4 h-4" />
                {gettext("Monthly Detail")}
              </button>
            </div>
          </div>
        </section>

        <%= if @view_mode == :overview do %>
          {overview_mode(assigns)}
        <% else %>
          {monthly_detail_mode(assigns)}
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp overview_mode(assigns) do
    ~H"""
    <div class="grid gap-4 md:grid-cols-4">
      <.summary_card
        title={gettext("Last month net")}
        value={format_money(assigns[:latest_month] && @latest_month.net)}
        detail={trend_text(net_trend(assigns[:latest_month], assigns[:prev_month]))}
      />
      <.summary_card
        title={gettext("Last month income")}
        value={format_money(assigns[:latest_month] && @latest_month.income)}
        detail={
          trend_text(
            value_diff(
              assigns[:latest_month] && @latest_month.income,
              assigns[:prev_month] && @prev_month.income
            )
          )
        }
      />
      <.summary_card
        title={gettext("Last month expenses")}
        value={format_money(assigns[:latest_month] && @latest_month.expense)}
        detail={
          trend_text(
            value_diff(
              assigns[:latest_month] && @latest_month.expense,
              assigns[:prev_month] && @prev_month.expense
            )
          )
        }
      />
      <.summary_card
        title={gettext("Closing balance")}
        value={format_money(assigns[:latest_month] && @latest_month.closing_balance)}
        detail={trend_text(closing_trend(assigns[:latest_month], assigns[:prev_month]))}
      />
    </div>

    <div class="rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm">
      <h2 class="text-xl font-semibold text-base-content mb-4">{gettext("Monthly summary")}</h2>
      <div class="rounded-xl bg-base-200/60 p-4 mb-4">
        <div id="history-monthly" phx-hook="Chart" class="h-80 w-full">
          <div id="history-monthly-chart" class="w-full h-80" phx-update="ignore" />
          <div id="history-monthly-data" hidden>{Jason.encode!(assigns[:monthly_chart] || %{})}</div>
        </div>
      </div>
    </div>

    <div class="grid gap-4 md:grid-cols-2">
      <div class="rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm">
        <h2 class="text-xl font-semibold text-base-content mb-4">
          {gettext("Income by category")}
        </h2>
        <%= if (assigns[:income_compare] || []) == [] do %>
          <p class="text-sm text-base-content/60">
            {gettext("No income data for the selected range.")}
          </p>
        <% else %>
          <div class="rounded-xl bg-base-200/60 p-4 mb-4">
            <div id="history-income" phx-hook="Chart" class="h-80 w-full">
              <div id="history-income-chart" class="w-full h-80" phx-update="ignore" />
              <div id="history-income-data" hidden>
                {Jason.encode!(assigns[:income_chart] || %{})}
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <div class="rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm">
        <h2 class="text-xl font-semibold text-base-content mb-4">
          {gettext("Expenses by category")}
        </h2>
        <%= if (assigns[:expense_compare] || []) == [] do %>
          <p class="text-sm text-base-content/60">
            {gettext("No expense data for the selected range.")}
          </p>
        <% else %>
          <div class="rounded-xl bg-base-200/60 p-4 mb-4">
            <div id="history-expenses" phx-hook="Chart" class="h-80 w-full">
              <div id="history-expenses-chart" class="w-full h-80" phx-update="ignore" />
              <div id="history-expenses-data" hidden>
                {Jason.encode!(assigns[:expense_chart] || %{})}
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <div class="rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm">
      <h2 class="text-xl font-semibold text-base-content mb-4">{gettext("Fixed income flows")}</h2>
      <%= if (assigns[:fixed_income] || []) == [] do %>
        <p class="text-sm text-base-content/60">
          {gettext("No fixed income data for the selected range.")}
        </p>
      <% else %>
        <div class="rounded-xl bg-base-200/60 p-4 mb-4">
          <div id="history-fixed-income" phx-hook="Chart" class="h-80 w-full">
            <div id="history-fixed-income-chart" class="w-full h-80" phx-update="ignore" />
            <div id="history-fixed-income-data" hidden>
              {Jason.encode!(assigns[:fixed_income_chart] || %{})}
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp monthly_detail_mode(assigns) do
    ~H"""
    <div>
      <div class="rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm mb-4">
        <div class="flex items-center justify-between mb-6">
          <button phx-click="prev_month" class="btn btn-circle btn-ghost">
            <.icon name="hero-chevron-left" class="w-6 h-6" />
          </button>
          <h2 class="text-2xl font-bold text-base-content">
            {month_label_full(@selected_year, @selected_month)}
          </h2>
          <button phx-click="next_month" class="btn btn-circle btn-ghost">
            <.icon name="hero-chevron-right" class="w-6 h-6" />
          </button>
        </div>

        <%= if assigns[:current_month_data] do %>
          <div class="grid gap-4 md:grid-cols-4">
            <.summary_card
              title={gettext("Net")}
              value={format_money(@current_month_data.net)}
              detail={
                trend_text(net_trend(assigns[:current_month_data], assigns[:previous_month_data]))
              }
            />
            <.summary_card
              title={gettext("Income")}
              value={format_money(@current_month_data.income)}
              detail={
                trend_text(
                  value_diff(
                    @current_month_data.income,
                    assigns[:previous_month_data] && @previous_month_data.income
                  )
                )
              }
            />
            <.summary_card
              title={gettext("Expenses")}
              value={format_money(@current_month_data.expense)}
              detail={
                trend_text(
                  value_diff(
                    @current_month_data.expense,
                    assigns[:previous_month_data] && @previous_month_data.expense
                  )
                )
              }
            />
            <.summary_card
              title={gettext("Closing balance")}
              value={format_money(@current_month_data.closing_balance)}
              detail={
                trend_text(closing_trend(assigns[:current_month_data], assigns[:previous_month_data]))
              }
            />
          </div>
        <% else %>
          <div class="text-center text-base-content/60 py-8">
            <p>{gettext("No data available for this month")}</p>
          </div>
        <% end %>
      </div>

      <div class="grid gap-4 md:grid-cols-2">
        <%= if assigns[:month_income_data] && assigns[:month_income_data] != [] do %>
          <div class="rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm">
            <h3 class="text-lg font-semibold text-base-content mb-4">
              {gettext("Income by category")}
            </h3>
            <div class="rounded-xl bg-base-200/60 p-4 mb-4">
              <div id="month-income-pie" phx-hook="Chart" class="h-80 w-full">
                <div id="month-income-pie-chart" class="w-full h-80" phx-update="ignore" />
                <div id="month-income-pie-data" hidden>
                  {Jason.encode!(assigns[:month_income_pie] || %{})}
                </div>
              </div>
            </div>
          </div>
        <% end %>
        <%= if assigns[:month_expense_data] && assigns[:month_expense_data] != [] do %>
          <div class="rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm">
            <h3 class="text-lg font-semibold text-base-content mb-4">
              {gettext("Expenses by category")}
            </h3>
            <div class="rounded-xl bg-base-200/60 p-4 mb-4">
              <div id="month-expense-pie" phx-hook="Chart" class="h-80 w-full">
                <div id="month-expense-pie-chart" class="w-full h-80" phx-update="ignore" />
                <div id="month-expense-pie-data" hidden>
                  {Jason.encode!(assigns[:month_expense_pie] || %{})}
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%= if assigns[:month_income_data] && assigns[:month_income_data] != [] do %>
        <div class="rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm mb-4">
          <h3 class="text-lg font-semibold text-base-content mb-4">
            {gettext("Income details")}
          </h3>
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full">
              <thead>
                <tr>
                  <th>{gettext("Category")}</th>
                  <th class="text-right">{gettext("Amount")}</th>
                </tr>
              </thead>
              <tbody>
                <%= for cat <- @month_income_data do %>
                  <tr>
                    <td>
                      <div class="flex items-center gap-2">
                        <div
                          class="w-3 h-3 rounded-full"
                          style={"background-color: #{cat.category_color}"}
                        >
                        </div>
                        {cat.category_name}
                      </div>
                    </td>
                    <td class="text-right font-semibold">{format_money(cat.total)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <%= if assigns[:month_expense_data] && assigns[:month_expense_data] != [] do %>
        <div class="rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm">
          <h3 class="text-lg font-semibold text-base-content mb-4">
            {gettext("Expense details")}
          </h3>
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full">
              <thead>
                <tr>
                  <th>{gettext("Category")}</th>
                  <th class="text-right">{gettext("Amount")}</th>
                </tr>
              </thead>
              <tbody>
                <%= for cat <- @month_expense_data do %>
                  <tr>
                    <td>
                      <div class="flex items-center gap-2">
                        <div
                          class="w-3 h-3 rounded-full"
                          style={"background-color: #{cat.category_color}"}
                        >
                        </div>
                        {cat.category_name}
                      </div>
                    </td>
                    <td class="text-right font-semibold">{format_money(cat.total)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp month_label_full(year, month) do
    months = [
      gettext("January"),
      gettext("February"),
      gettext("March"),
      gettext("April"),
      gettext("May"),
      gettext("June"),
      gettext("July"),
      gettext("August"),
      gettext("September"),
      gettext("October"),
      gettext("November"),
      gettext("December")
    ]

    "#{Enum.at(months, month - 1)} #{year}"
  end

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :detail, :any

  defp summary_card(assigns) do
    ~H"""
    <div class="rounded-2xl border border-base-300 bg-base-100/80 p-4 shadow-sm">
      <p class="text-sm opacity-70">{@title}</p>
      <p class="text-xl font-semibold">{@value || "-"}</p>
      <p class="text-xs opacity-70">{@detail}</p>
    </div>
    """
  end

  defp trend_text(nil), do: "-"
  defp trend_text(value) when is_number(value) and value == 0, do: gettext("No change")
  defp trend_text(value) when is_number(value) and value > 0, do: "+" <> format_money(value)
  defp trend_text(value) when is_number(value), do: format_money(value)

  defp value_diff(nil, _prev), do: nil
  defp value_diff(_current, nil), do: nil
  defp value_diff(current, prev), do: current - prev

  defp format_money(nil), do: "-"

  defp format_money(value) do
    PersonalFinance.Utils.CurrencyUtils.format_money(value)
  end

  defp format_percent(nil), do: "-"

  defp format_percent(value) do
    :io_lib.format("~.1f%%", [value]) |> IO.iodata_to_binary()
  end
end
