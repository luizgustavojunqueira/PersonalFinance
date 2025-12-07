defmodule PersonalFinanceWeb.PlaygroundLive.Valuation do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Math.Valuation
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
         page_title: gettext("Present/Future Value") <> " - #{ledger.name}",
         form_data: default_form(),
         result: nil
       )}
    end
  end

  @impl true
  def handle_event("change", %{"valuation" => params}, socket) do
    socket = assign(socket, form_data: params)

    {:noreply, run_calculation(socket)}
  end

  defp run_calculation(socket) do
    params = socket.assigns.form_data

    mapped_params = %{
      mode: if(params["mode"] == "fv", do: :fv, else: :pv),
      amount: safe_float(params["amount"]),
      rate: safe_float(params["rate"]),
      rate_period: to_atom(params["rate_period"], :month),
      duration: safe_int(params["duration"]),
      duration_unit: to_atom(params["duration_unit"], :month)
    }

    result =
      if mapped_params.duration > 0 and mapped_params.amount > 0 do
        Valuation.calculate(mapped_params)
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

  defp to_atom(nil, default), do: default
  defp to_atom(value, default) when is_binary(value) do
    case value do
      "month" -> :month
      "year" -> :year
      _ -> default
    end
  end

  defp default_form do
    %{
      "mode" => "pv",
      "amount" => "1000",
      "rate" => "1",
      "rate_period" => "month",
      "duration" => "12",
      "duration_unit" => "month"
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
                  {gettext("Present/Future Value")}
                </h1>
                <p class="text-sm text-base-content/70 max-w-xl">
                  {gettext("Calculate how much a single amount is worth today or in the future, given a rate and time.")}
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
            as={:valuation}
            phx-change="change"
            class="bg-base-100 border border-base-300 rounded-2xl p-5 space-y-4 lg:col-span-1 shadow-sm"
          >
            <.input
              type="select"
              name="valuation[mode]"
              label={gettext("What do you want to find?")}
              value={@form_data["mode"]}
              options={[
                {gettext("Find present value (discount a future amount)"), "pv"},
                {gettext("Find future value (grow a present amount)"), "fv"}
              ]}
            />

            <div class="space-y-1" phx-update="ignore" id="valuation-amount-container">
              <label class="text-sm font-medium" for="valuation_amount_input">
                <%= if @form_data["mode"] == "fv" do %>
                  {gettext("Present amount (today)")}
                <% else %>
                  {gettext("Future amount (target)")}
                <% end %>
              </label>
              <input
                id="valuation_amount_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="valuation[amount]"
              />
              <input type="hidden" name="valuation[amount]" value={@form_data["amount"]} />
            </div>

            <.input
              name="valuation[rate]"
              type="number"
              label={gettext("Rate (%)")}
              value={@form_data["rate"]}
              min="0"
              step="0.01"
            />

            <.input
              type="select"
              name="valuation[rate_period]"
              label={gettext("Rate period")}
              value={@form_data["rate_period"]}
              options={[
                {gettext("per month"), "month"},
                {gettext("per year"), "year"}
              ]}
            />

            <.input
              name="valuation[duration]"
              type="number"
              label={gettext("Time")}
              value={@form_data["duration"]}
              min="1"
              step="1"
            />

            <.input
              type="select"
              name="valuation[duration_unit]"
              label={gettext("Unit")}
              value={@form_data["duration_unit"]}
              options={[
                {gettext("months"), "month"},
                {gettext("years"), "year"}
              ]}
            />
          </.form>

          <%= if @result do %>
            <div class="lg:col-span-2 space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Present value")}</div>
                  <div class="mt-2 text-2xl font-bold text-success">
                    {CurrencyUtils.format_money(@result.present_value)}
                  </div>
                </div>

                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Future value")}</div>
                  <div class="mt-2 text-2xl font-bold text-base-content">
                    {CurrencyUtils.format_money(@result.future_value)}
                  </div>
                </div>

                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Total growth / discount")}</div>
                  <div class="mt-2 text-2xl font-bold text-primary">
                    {CurrencyUtils.format_money(@result.total_interest)}
                  </div>
                </div>

                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">{gettext("Factor")}</div>
                  <div class="mt-2 text-2xl font-bold text-base-content">
                    {:erlang.float_to_binary(@result.discount_factor, decimals: 4)}
                  </div>
                  <p class="text-xs text-base-content/60 mt-1">
                    <%= if @form_data["mode"] == "fv" do %>
                      {gettext("Accumulation factor (FV = PV x factor)")}
                    <% else %>
                      {gettext("Discount factor (PV = FV / factor)")}
                    <% end %>
                  </p>
                </div>
              </div>

              <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm h-full">
                <div class="flex items-center justify-between mb-2">
                  <h2 class="font-semibold text-base">{gettext("Value over time")}</h2>
                  <p class="text-xs text-base-content/60">
                    {gettext("How the amount evolves with this rate and time")}
                  </p>
                </div>
                <div id="valuation-chart" phx-hook="Chart" class="w-full h-80">
                  <div id="valuation-chart-chart" class="w-full h-full" phx-update="ignore"></div>
                  <div id="valuation-chart-data" hidden>
                    {Jason.encode!(chart_option(@result.timeline, @form_data["duration_unit"], @form_data["mode"]))}
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

  defp chart_option(timeline, duration_unit, mode) do
    {periods, balances} =
      case duration_unit do
        "year" ->
          yearly_points =
            timeline
            |> Enum.chunk_every(12, 12, :discard)
            |> Enum.with_index(1)

          labels = Enum.map(yearly_points, fn {_chunk, idx} -> "#{idx}y" end)
          values =
            Enum.map(yearly_points, fn {chunk, _idx} ->
              chunk |> List.last() |> Map.get(:balance) |> Float.round(2)
            end)

          {labels, values}

        _ ->
          {
            Enum.map(timeline, fn point -> "#{point.period}m" end),
            Enum.map(timeline, fn point -> Float.round(point.balance, 2) end)
          }
      end

    %{
      tooltip: %{trigger: "axis"},
      legend: %{data: [if(mode == "fv", do: "Future", else: "Present")], show: false},
      xAxis: %{type: "category", data: periods, name: gettext("Time")},
      yAxis: %{type: "value", name: gettext("Value (R$)")},
      series: [
        %{
          name: if(mode == "fv", do: "Future", else: "Present"),
          type: "line",
          data: balances,
          smooth: true,
          lineStyle: %{width: 3},
          itemStyle: %{color: "#3b82f6"}
        }
      ]
    }
  end
end
