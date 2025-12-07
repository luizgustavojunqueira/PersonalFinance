defmodule PersonalFinanceWeb.PlaygroundLive.DebtCompare do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Math.Debts
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
         page_title: gettext("Finance or pay upfront?") <> " - #{ledger.name}",
         form_data: default_form(),
         result: nil
       )}
    end
  end

  @impl true
  def handle_event("change", %{"debt_compare" => params}, socket) do
    socket = assign(socket, form_data: params)

    {:noreply, run_calculation(socket)}
  end

  defp run_calculation(socket) do
    params = socket.assigns.form_data

    price = safe_float(params["price"])
    discount_pct = safe_float(params["discount_pct"])
    installments = safe_int(params["installments"])
    finance_rate = safe_float(params["finance_rate"])
    invest_rate = safe_float(params["invest_rate"])

    should_calculate = price > 0 and installments > 0 and finance_rate >= 0 and invest_rate >= 0

    result =
      if should_calculate do
        mapped_params = %{
          price: price,
          discount_pct: discount_pct,
          installments: installments,
          finance_rate: finance_rate,
          invest_rate: invest_rate
        }

        Debts.compare(mapped_params)
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
      "price" => "",
      "discount_pct" => "0",
      "installments" => "12",
      "finance_rate" => "",
      "invest_rate" => ""
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
                  {gettext("Finance or pay upfront?")}
                </h1>
                <p class="text-sm text-base-content/70 max-w-xl">
                  {gettext("Compare financing with installments while investing your cash versus paying upfront with a discount.")}
                </p>
                <div class="alert alert-info text-xs mt-2 py-2 px-3">
                  <.icon name="hero-information-circle" class="w-4 h-4" />
                  <span>
                    {gettext("Usually paying upfront is better, unless the financing rate is very low or your investment return is very high.")}
                  </span>
                </div>
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
            as={:debt_compare}
            phx-change="change"
            class="bg-base-100 border border-base-300 rounded-2xl p-5 space-y-4 lg:col-span-1 shadow-sm"
          >
            <div class="space-y-1" phx-update="ignore" id="debt-amount-input-container">
              <label class="text-sm font-medium" for="debt_amount_input">{gettext("Purchase price")}</label>
              <input
                id="debt_amount_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="debt_compare[price]"
              />
              <input
                type="hidden"
                name="debt_compare[price]"
                value={@form_data["price"]}
              />
            </div>

            <.input
              name="debt_compare[discount_pct]"
              type="number"
              label={gettext("Upfront discount (%) (optional)")}
              value={@form_data["discount_pct"]}
              min="0"
              step="0.01"
            />

            <.input
              name="debt_compare[installments]"
              type="number"
              label={gettext("Number of installments (months)")}
              value={@form_data["installments"]}
              min="1"
              step="1"
            />

            <.input
              name="debt_compare[finance_rate]"
              type="number"
              label={gettext("Installment interest (% per month)")}
              value={@form_data["finance_rate"]}
              min="0"
              step="0.01"
            />

            <.input
              name="debt_compare[invest_rate]"
              type="number"
              label={gettext("Investment return (% per month)")}
              value={@form_data["invest_rate"]}
              min="0"
              step="0.01"
            />
          </.form>

          <%= if @result do %>
            <div class="lg:col-span-2 space-y-4">
              <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm flex flex-col md:flex-row md:items-center md:justify-between gap-3">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Best option")}</p>
                  <div class="mt-2 text-2xl font-bold text-base-content">
                    <%= case @result.winner do %>
                      <% :finance_invest -> %>{gettext("Finance and invest")}
                      <% :upfront -> %>{gettext("Pay upfront")}
                      <% :tie -> %>{gettext("Tie")}
                    <% end %>
                  </div>
                  <p class="text-sm text-base-content/60 mt-1">
                    {gettext("Net cost difference")}: {CurrencyUtils.format_money(abs(@result.diff))}
                  </p>
                </div>
                <div class="text-xs text-base-content/60">
                  {gettext("Horizon")}: {@result.installments} {gettext("months")}
                </div>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Finance and invest")}</p>
                      <p class="text-sm text-base-content/60">{gettext("You have the money: finance and invest it, paying installments from returns.")}</p>
                    </div>
                  </div>
                  <div class="mt-3 space-y-2">
                    <p class="text-sm text-base-content/70">{gettext("Monthly installment")}</p>
                    <div class="text-xl font-semibold text-base-content">{CurrencyUtils.format_money(@result.finance_with_invest.payment)}</div>
                    <p class="text-sm text-base-content/70">{gettext("Total paid in installments")}</p>
                    <div class="text-xl font-semibold text-base-content">{CurrencyUtils.format_money(@result.finance_with_invest.total_paid)}</div>
                    <p class="text-sm text-base-content/70">{gettext("Investment balance after all installments")}</p>
                    <div class="text-lg font-semibold text-success">{CurrencyUtils.format_money(@result.finance_with_invest.final_balance)}</div>
                    <div class="divider my-2"></div>
                    <p class="text-sm font-semibold text-base-content/70">{gettext("Net cost (paid - remaining)")}</p>
                    <div class="text-2xl font-bold text-primary">{CurrencyUtils.format_money(@result.finance_with_invest.net_position)}</div>
                  </div>
                </div>

                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Pay upfront")}</p>
                      <p class="text-sm text-base-content/60">{gettext("You have the money: pay upfront and get the discount.")}</p>
                    </div>
                  </div>
                  <div class="mt-3 space-y-2">
                    <%= if @result.upfront.discount_amount > 0 do %>
                      <p class="text-sm text-base-content/70">{gettext("Discount amount")}</p>
                      <div class="text-lg font-semibold text-success">{CurrencyUtils.format_money(@result.upfront.discount_amount)}</div>
                    <% end %>
                    <p class="text-sm text-base-content/70">{gettext("Upfront cost (after discount)")}</p>
                    <div class="text-xl font-semibold text-base-content">{CurrencyUtils.format_money(@result.upfront.upfront_cost)}</div>
                    <div class="divider my-2"></div>
                    <p class="text-sm font-semibold text-base-content/70">{gettext("Net cost")}</p>
                    <div class="text-2xl font-bold text-primary">{CurrencyUtils.format_money(@result.upfront.net_position)}</div>
                  </div>
                </div>
              </div>

              <%= if @result.winner == :finance_invest do %>
                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm h-full">
                  <div class="flex items-center justify-between mb-2">
                    <h2 class="font-semibold text-base">{gettext("Monthly balance evolution (financing)")}</h2>
                    <p class="text-xs text-base-content/60">
                      {gettext("Compare financing with and without investing the cash.")}
                    </p>
                  </div>
                  <div id="debt-compare-chart" phx-hook="Chart" class="w-full h-80">
                    <div id="debt-compare-chart-chart" class="w-full h-full" phx-update="ignore" />
                    <div id="debt-compare-chart-data" hidden>
                      {Jason.encode!(chart_option(@result.finance_with_invest.timeline, @result.finance_with_invest.payment))}
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp chart_option(finance_timeline, payment) do
    periods = Enum.map(finance_timeline, & &1.period)
    with_invest_balances = Enum.map(finance_timeline, fn point -> Float.round(point.balance, 2) end)

    # Simular cenário sem investir: saldo sempre negativo acumulando parcelas
    no_invest_balances =
      Enum.map(1..length(finance_timeline), fn period ->
        Float.round(-payment * period, 2)
      end)

    %{
      tooltip: %{trigger: "axis"},
      legend: %{data: ["Financiar e investir (saldo)", "Financiar sem investir (custo acumulado)"]},
      xAxis: %{type: "category", data: periods, name: "Mês"},
      yAxis: [%{type: "value", name: "Saldo/Custo"}],
      series: [
        %{name: "Financiar e investir (saldo)", type: "line", data: with_invest_balances, smooth: true},
        %{name: "Financiar sem investir (custo acumulado)", type: "line", data: no_invest_balances, smooth: true, lineStyle: %{type: "dashed"}}
      ]
    }
  end
end
