defmodule PersonalFinanceWeb.PlaygroundLive.Fi do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Math.Retirement
  alias PersonalFinance.Utils.CurrencyUtils
  alias Jason

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
      {:ok,
       assign(socket,
         ledger: ledger,
         page_title: gettext("Financial Independence (FI)") <> " - #{ledger.name}",
         form_data: default_form(),
         result: nil
       )}
    end
  end

  @impl true
  def handle_event("change", %{"fi" => params}, socket) do
    socket = assign(socket, form_data: params)

    {:noreply, run_calculation(socket)}
  end

  defp run_calculation(socket) do
    params = socket.assigns.form_data

    monthly_expenses = safe_float(params["monthly_expenses"])
    withdrawal_rate = safe_float(params["withdrawal_rate"])
    current_wealth = safe_float(params["current_wealth"])
    monthly_contribution = safe_float(params["monthly_contribution"])
    return_rate = safe_float(params["return_rate"])
    max_years = safe_int(params["max_years"])

    should_calculate = monthly_expenses > 0 and withdrawal_rate > 0 and monthly_contribution >= 0 and return_rate >= 0

    result =
      if should_calculate do
        mapped_params = %{
          monthly_expenses: monthly_expenses,
          withdrawal_rate: withdrawal_rate,
          current_wealth: current_wealth,
          monthly_contribution: monthly_contribution,
          return_rate: return_rate,
          max_years: if(max_years > 0, do: max_years, else: 50)
        }

        Retirement.calculate_fi(mapped_params)
      else
        nil
      end

    assign(socket, result: result)
  end

  defp safe_float(nil), do: 0.0
  defp safe_float(""), do: 0.0

  defp safe_float(value) when is_binary(value) do
    cleaned =
      value
      |> String.trim()
      |> then(fn v ->
        if String.contains?(v, ",") do
          v
          |> String.replace(".", "")
          |> String.replace(",", ".")
        else
          v
        end
      end)

    case Float.parse(cleaned) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp safe_float(value) when is_integer(value), do: value * 1.0
  defp safe_float(value) when is_float(value), do: value

  defp safe_int(nil), do: 0
  defp safe_int(""), do: 0

  defp safe_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp safe_int(value) when is_integer(value), do: value
  defp safe_int(value) when is_float(value), do: trunc(value)

  defp default_form do
    %{
      "monthly_expenses" => "",
      "withdrawal_rate" => "4",
      "current_wealth" => "",
      "monthly_contribution" => "",
      "return_rate" => "",
      "max_years" => "20"
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} show_sidebar={true} ledger={@ledger}>
      <div class="min-h-screen pb-12 space-y-6">
        <section class="bg-base-100/80 border border-base-300 rounded-2xl p-6 shadow-sm mt-4">
          <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <div class="space-y-2">
              <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
                {gettext("Playground")}
              </p>
              <div class="space-y-1">
                <h1 class="text-xl font-bold text-base-content">
                  {gettext("Financial Independence (FI)")}
                </h1>
                <p class="text-sm text-base-content/70 max-w-xl">
                  {gettext("Calculate how much wealth you need to live off passive income and when you'll reach FI.")}
                </p>
              </div>
            </div>

            <div class="flex gap-2 justify-end">
              <.link
                navigate={~p"/ledgers/#{@ledger.id}/playground"}
                class="btn btn-ghost btn-sm gap-1"
              >
                <.icon name="hero-arrow-uturn-left" class="w-4 h-4" />
                {gettext("Back to tools")}
              </.link>
            </div>
          </div>
        </section>

        <section class="grid grid-cols-1 lg:grid-cols-3 gap-4 items-start">
          <.form
            for={%{}}
            as={:fi}
            phx-change="change"
            class="bg-base-100 border border-base-300 rounded-2xl p-5 space-y-4 lg:col-span-1 shadow-sm"
          >
            <div class="space-y-1" phx-update="ignore" id="fi-monthly-expenses-container">
              <label class="text-sm font-medium" for="fi_monthly_expenses_input">{gettext("Desired monthly expenses")}</label>
              <input
                id="fi_monthly_expenses_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="fi[monthly_expenses]"
              />
              <input
                type="hidden"
                name="fi[monthly_expenses]"
                value={@form_data["monthly_expenses"]}
              />
              <p class="text-xs text-base-content/60">{gettext("How much you want to spend per month living off investments")}</p>
            </div>

            <.input
              name="fi[withdrawal_rate]"
              type="number"
              label={gettext("Safe withdrawal rate (% per year)")}
              value={@form_data["withdrawal_rate"]}
              min="0"
              step="0.1"
            />
            <p class="text-xs text-base-content/60 -mt-2">{gettext("Defines how much wealth you need. Classic: 4% (need 25x annual expenses). Lower rate = more wealth needed, safer.")}</p>

            <div class="space-y-1" phx-update="ignore" id="fi-current-wealth-container">
              <label class="text-sm font-medium" for="fi_current_wealth_input">{gettext("Current wealth")}</label>
              <input
                id="fi_current_wealth_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="fi[current_wealth]"
              />
              <input
                type="hidden"
                name="fi[current_wealth]"
                value={@form_data["current_wealth"]}
              />
              <p class="text-xs text-base-content/60">{gettext("Total wealth you have today (cash + investments)")}</p>
            </div>

            <div class="space-y-1" phx-update="ignore" id="fi-monthly-contribution-container">
              <label class="text-sm font-medium" for="fi_monthly_contribution_input">{gettext("Monthly contribution")}</label>
              <input
                id="fi_monthly_contribution_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="fi[monthly_contribution]"
              />
              <input
                type="hidden"
                name="fi[monthly_contribution]"
                value={@form_data["monthly_contribution"]}
              />
              <p class="text-xs text-base-content/60">{gettext("How much you'll invest every month")}</p>
            </div>

            <.input
              name="fi[return_rate]"
              type="number"
              label={gettext("Expected return (% per month)")}
              value={@form_data["return_rate"]}
              min="0"
              step="0.01"
            />
            <p class="text-xs text-base-content/60 -mt-2">{gettext("Expected monthly return on your investments")}</p>

            <.input
              name="fi[max_years]"
              type="number"
              label={gettext("Maximum time horizon (years)")}
              value={@form_data["max_years"]}
              min="1"
              step="1"
            />
            <p class="text-xs text-base-content/60 -mt-2">{gettext("Limit calculation to this many years (default: 50)")}</p>
          </.form>

          <%= if @result do %>
            <div class="lg:col-span-2 space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("FI Target")}</div>
                  <div class="mt-2 text-2xl font-bold text-primary">
                    {CurrencyUtils.format_money(@result.target_wealth)}
                  </div>
                  <p class="text-xs text-base-content/60 mt-1">
                    {gettext("Wealth needed for")} {CurrencyUtils.format_money(@result.monthly_passive_income)}/mês
                  </p>
                </div>

                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Time to FI")}</div>
                  <%= if @result.years_to_fi do %>
                    <div class="mt-2 text-2xl font-bold text-success">
                      {format_years(@result.years_to_fi)}
                    </div>
                    <p class="text-xs text-base-content/60 mt-1">
                      {gettext("You'll reach FI!")}
                    </p>
                  <% else %>
                    <div class="mt-2 text-xl font-semibold text-warning">
                      {gettext("Not reached")}
                    </div>
                    <p class="text-xs text-base-content/60 mt-1">
                      {gettext("In the time horizon set")}
                    </p>
                  <% end %>
                </div>

                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Current Progress")}</div>
                  <div class="mt-2 text-2xl font-bold text-base-content">
                    {Float.round(@result.current_progress, 1)}%
                  </div>
                  <p class="text-xs text-base-content/60 mt-1">
                    {CurrencyUtils.format_money(@result.current_wealth)} / {CurrencyUtils.format_money(@result.target_wealth)}
                  </p>
                </div>
              </div>

              <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Projected Wealth")}</div>
                <div class="mt-2 space-y-2">
                  <div>
                    <p class="text-sm text-base-content/70">{gettext("Final balance")}</p>
                    <div class="text-xl font-bold text-base-content">{CurrencyUtils.format_money(@result.final_balance)}</div>
                  </div>
                  <div>
                    <p class="text-sm text-base-content/70">{gettext("Total contributed")}</p>
                    <div class="text-lg font-semibold text-base-content">{CurrencyUtils.format_money(@result.total_contributed)}</div>
                  </div>
                  <div>
                    <p class="text-sm text-base-content/70">{gettext("Earnings from returns")}</p>
                    <div class="text-lg font-semibold text-success">{CurrencyUtils.format_money(@result.total_earnings)}</div>
                  </div>
                </div>
              </div>

              <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm h-full">
                <div class="flex items-center justify-between mb-2">
                  <h2 class="font-semibold text-base">{gettext("Wealth Evolution")}</h2>
                  <p class="text-xs text-base-content/60">
                    {gettext("Your path to financial independence")}
                  </p>
                </div>
                <div id="fi-chart" phx-hook="Chart" class="w-full h-80">
                  <div id="fi-chart-chart" class="w-full h-full" phx-update="ignore" />
                  <div id="fi-chart-data" hidden>
                    {Jason.encode!(chart_option(@result.timeline, @result.timeline_with_withdrawals, @result.target_wealth, @result.months_to_fi))}
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp format_years(years) when years < 1, do: "#{trunc(years * 12)} #{gettext("months")}"
  defp format_years(years) do
    whole_years = trunc(years)
    remaining_months = trunc((years - whole_years) * 12)

    if remaining_months > 0 do
      "#{whole_years} #{gettext("years")} #{remaining_months} #{gettext("months")}"
    else
      "#{whole_years} #{gettext("years")}"
    end
  end

  defp chart_option(timeline, timeline_with_withdrawals, target_wealth, months_to_fi) do
    periods = Enum.map(timeline, fn point ->
      years = point.period / 12.0
      if years == trunc(years), do: "#{trunc(years)}y", else: "#{point.period}m"
    end)

    balances = Enum.map(timeline, fn point -> Float.round(point.balance, 2) end)
    target_line = Enum.map(timeline, fn _ -> Float.round(target_wealth, 2) end)

    series = [
      %{
        name: "Sem retiradas",
        type: "line",
        data: balances,
        smooth: true,
        lineStyle: %{width: 2, type: "dashed"},
        itemStyle: %{color: "#94a3b8"}
      },
      %{
        name: "Meta FI",
        type: "line",
        data: target_line,
        lineStyle: %{type: "dashed", color: "#ef4444"},
        itemStyle: %{color: "#ef4444"}
      }
    ]

    # Add timeline with withdrawals if available
    series_with_withdrawals =
      if timeline_with_withdrawals do
        balances_with_withdrawals = Enum.map(timeline_with_withdrawals, fn point -> Float.round(point.balance, 2) end)

        series ++ [
          %{
            name: "Com retiradas",
            type: "line",
            data: balances_with_withdrawals,
            smooth: true,
            lineStyle: %{width: 3},
            itemStyle: %{color: "#3b82f6"}
          }
        ]
      else
        # If no withdrawals timeline, use original timeline as main line
        List.update_at(series, 0, fn s ->
          %{s | name: "Patrimônio", lineStyle: %{width: 3}, itemStyle: %{color: "#3b82f6"}}
        end)
      end

    # Add marker at FI point if reached
    series_with_marker =
      if months_to_fi do
        fi_point_index = Enum.find_index(timeline, fn p -> p.period >= months_to_fi end)

        if fi_point_index do
          target_series_index = if timeline_with_withdrawals, do: 2, else: 0

          update_in(series_with_withdrawals, [Access.at(target_series_index), :markPoint], fn _ ->
            %{
              data: [
                %{
                  coord: [fi_point_index, Enum.at(if(timeline_with_withdrawals, do: Enum.map(timeline_with_withdrawals, &Float.round(&1.balance, 2)), else: balances), fi_point_index)],
                  value: "FI!",
                  itemStyle: %{color: "#22c55e"}
                }
              ]
            }
          end)
        else
          series_with_withdrawals
        end
      else
        series_with_withdrawals
      end

    legend_data = if timeline_with_withdrawals do
      ["Sem retiradas", "Meta FI", "Com retiradas"]
    else
      ["Patrimônio", "Meta FI"]
    end

    %{
      tooltip: %{trigger: "axis"},
      legend: %{data: legend_data},
      xAxis: %{type: "category", data: periods, name: "Tempo"},
      yAxis: %{type: "value", name: "Patrimônio (R$)"},
      series: series_with_marker
    }
  end
end
