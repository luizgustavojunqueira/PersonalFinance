defmodule PersonalFinanceWeb.PlaygroundLive.Interest do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Math.Investments
  alias PersonalFinance.Utils.CurrencyUtils

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
         page_title: gettext("Interest simulator") <> " - #{ledger.name}",
         form_data: default_form(),
         result: nil
       )}
    end
  end
  @impl true
  def handle_event("change", %{"simulation" => params}, socket) do
    socket = assign(socket, form_data: params)

    {:noreply, run_simulation(socket)}
  end

  defp run_simulation(socket) do
    params = socket.assigns.form_data

    mapped_params = %{
      principal: params["principal"],
      rate: params["rate"],
      rate_period: (params["rate_period"] || "month") |> String.to_existing_atom(),
      duration: safe_int(params["duration"]),
      duration_unit: (params["duration_unit"] || "month") |> String.to_existing_atom(),
      monthly_contribution: params["monthly_contribution"],
      simple_interest: params["simple_interest"] == "true"
    }

    result =
      if mapped_params.duration > 0 do
        Investments.simulate(mapped_params)
      else
        nil
      end

    assign(socket, result: result)
  end

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
      "principal" => "1000",
      "rate" => "1",
      "rate_period" => "month",
      "duration" => "12",
      "duration_unit" => "month",
      "monthly_contribution" => "0",
      "simple_interest" => "false"
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
                  {gettext("Interest simulator")}
                </h1>
                <p class="text-sm text-base-content/70 max-w-xl">
                  {gettext("Simulate how your investment evolves over time with simple or compound interest, monthly contributions and different time units.")}
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
            as={:simulation}
            phx-change="change"
            class="bg-base-100 border border-base-300 rounded-2xl p-5 space-y-4 lg:col-span-1 shadow-sm"
          >
          <div class="space-y-1" phx-update="ignore" id="principal-input-container">
            <label class="text-sm font-medium" for="principal_input">{gettext("Initial amount")}</label>
            <input
              id="principal_input"
              type="text"
              class="input input-bordered w-full"
              phx-hook="MoneyInput"
              data-hidden-name="simulation[principal]"
            />
            <input
              type="hidden"
              name="simulation[principal]"
              value={@form_data["principal"]}
            />
          </div>

          <.input
            name="simulation[rate]"
            type="number"
            label={gettext("Interest rate (%)")}
            value={@form_data["rate"]}
            min="0"
            step="0.01"
          />

          <.input
            type="select"
            name="simulation[rate_period]"
            label={gettext("Rate period")}
            value={@form_data["rate_period"]}
            options={[
              {gettext("per month"), "month"},
              {gettext("per year"), "year"}
            ]}
          />

          <.input
            name="simulation[duration]"
            type="number"
            label={gettext("Duration")}
            value={@form_data["duration"]}
            min="1"
            step="1"
          />

          <.input
            type="select"
            name="simulation[duration_unit]"
            label={gettext("Unit")}
            value={@form_data["duration_unit"]}
            options={[
              {gettext("months"), "month"},
              {gettext("years"), "year"}
            ]}
          />

          <div class="space-y-1" phx-update="ignore" id="monthly-contribution-input-container">
            <label class="text-sm font-medium" for="monthly_contribution_input">{gettext("Monthly contribution (optional)")}</label>
            <input
              id="monthly_contribution_input"
              type="text"
              class="input input-bordered w-full"
              phx-hook="MoneyInput"
              data-hidden-name="simulation[monthly_contribution]"
            />
            <input
              type="hidden"
              name="simulation[monthly_contribution]"
              value={@form_data["monthly_contribution"]}
            />
          </div>

          <div class="flex items-center gap-2 col-span-1">
            <label class="label cursor-pointer flex items-center gap-2">
              <input
                type="checkbox"
                name="simulation[simple_interest]"
                value="true"
                checked={@form_data["simple_interest"] == "true"}
                class="checkbox checkbox-primary"
              />
              <span class="label-text">{gettext("Use simple interest instead of compound")}</span>
            </label>
          </div>
        </.form>

        <%= if @result do %>
          <div class="lg:col-span-2 space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Final balance")}</div>
                <div class="mt-2 text-2xl font-bold text-base-content">
                  {CurrencyUtils.format_money(@result.final_balance)}
                </div>
              </div>
              <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Total invested")}</div>
                <div class="mt-2 text-2xl font-bold text-base-content">
                  {CurrencyUtils.format_money(@result.total_invested)}
                </div>
              </div>
              <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Interest earned")}</div>
                <div class="mt-2 text-2xl font-bold text-success">
                  {CurrencyUtils.format_money(@result.total_interest)}
                </div>
              </div>
            </div>

            <div class="card bg-base-100 border border-base-300 p-4 mt-2 rounded-2xl shadow-sm h-full">
              <div class="flex items-center justify-between mb-2">
                <h2 class="font-semibold text-base">{gettext("Evolution over time")}</h2>
                <p class="text-xs text-base-content/60">
                  {gettext("Bars show total balance; line shows interest per period.")}
                </p>
              </div>
              <div id="interest-chart" phx-hook="Chart" class="w-full h-80">
                <div id="interest-chart-chart" class="w-full h-full" phx-update="ignore" />
                <div id="interest-chart-data" hidden>
                  {Jason.encode!(chart_option(@result.timeline, @form_data["rate_period"], @form_data["duration_unit"]))}
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

  defp chart_option(timeline, _rate_period, duration_unit) do
    {periods, balances, deltas} =
      case duration_unit do
        "year" ->
          timeline
          |> Enum.chunk_every(12)
          |> Enum.with_index(1)
          |> Enum.map(fn {months, year_index} ->
            last = List.last(months)

            %{
              period: year_index,
              balance: last.balance,
              delta_interest:
                Enum.reduce(months, 0.0, fn point, acc -> point.delta_interest + acc end)
            }
          end)
          |> then(fn yearly ->
            periods = Enum.map(yearly, & &1.period)
            balances = Enum.map(yearly, fn point -> Float.round(point.balance, 2) end)
            deltas = Enum.map(yearly, fn point -> Float.round(point.delta_interest, 2) end)

            {periods, balances, deltas}
          end)

        _ ->
          periods = Enum.map(timeline, & &1.period)
          balances = Enum.map(timeline, fn point -> Float.round(point.balance, 2) end)
          deltas = Enum.map(timeline, fn point -> Float.round(point.delta_interest, 2) end)

          {periods, balances, deltas}
      end

    %{
      tooltip: %{
        trigger: "axis"
      },
      legend: %{
        data: ["Saldo acumulado", "Juros no mês"]
      },
      xAxis: %{
        type: "category",
        data: periods
      },
      yAxis: [
        %{
          type: "value",
          name: "Saldo"
        },
        %{
          type: "value",
          name: "Juros no mês"
        }
      ],
      series: [
        %{
          name: "Saldo acumulado",
          type: "bar",
          data: balances
        },
        %{
          name: "Juros no mês",
          type: "line",
          yAxisIndex: 1,
          data: deltas
        }
      ]
    }
  end
end
