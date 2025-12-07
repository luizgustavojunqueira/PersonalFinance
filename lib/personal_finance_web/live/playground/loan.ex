defmodule PersonalFinanceWeb.PlaygroundLive.Loan do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Math.Loans
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
         page_title: gettext("Loan simulator") <> " - #{ledger.name}",
         form_data: default_form(),
         result: nil,
         extra_warning: nil
       )}
    end
  end

  @impl true
  def handle_event("change", %{"loan" => params}, socket) do
    socket = assign(socket, form_data: params)

    {:noreply, run_calculation(socket)}
  end

  defp run_calculation(socket) do
    params = socket.assigns.form_data

    principal = safe_float(params["principal"])
    rate = safe_float(params["rate"])
    duration = safe_int(params["duration"])
    {extra, extra_warning} = clamp_extra(safe_float(params["extra"]), principal)

    method = normalize_method(params["method"])
    compare_baseline? = extra > 0

    should_calculate = principal > 0 and rate > 0 and duration > 0

    result =
      if should_calculate do
        mapped_params = %{
          principal: principal,
          rate: rate,
          rate_period: normalize_rate_period(params["rate_period"]),
          duration: duration,
          duration_unit: normalize_duration_unit(params["duration_unit"]),
          extra: extra
        }

        baseline_params = Map.put(mapped_params, :extra, 0)

        case method do
          :price -> %{method: :price, price: Loans.price_amortization(mapped_params), baseline: Loans.price_amortization(baseline_params), compare_baseline?: compare_baseline?}
          :sac -> %{method: :sac, sac: Loans.sac_amortization(mapped_params), baseline: Loans.sac_amortization(baseline_params), compare_baseline?: compare_baseline?}
          :compare -> %{
            method: :compare,
            price: Loans.price_amortization(mapped_params),
            sac: Loans.sac_amortization(mapped_params),
            baseline_price: Loans.price_amortization(baseline_params),
            baseline_sac: Loans.sac_amortization(baseline_params),
            compare_baseline?: compare_baseline?
          }
        end
      else
        nil
      end

    socket
    |> assign(extra_warning: extra_warning)
    |> assign(result: result)
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

  defp clamp_extra(extra, principal) do
    cond do
      extra < 0 -> {0.0, gettext("Extra não pode ser negativo; usando 0.")}
      extra == 0 -> {0.0, nil}
      extra > principal and principal > 0 -> {extra, gettext("Extra é maior que o saldo inicial; será limitado pela quitação antecipada.")}
      true -> {extra, nil}
    end
  end

  defp normalize_rate_period("year"), do: :year
  defp normalize_rate_period(_), do: :month

  defp normalize_duration_unit("year"), do: :year
  defp normalize_duration_unit(_), do: :month

  defp normalize_method("sac"), do: :sac
  defp normalize_method("compare"), do: :compare
  defp normalize_method(_), do: :price

  defp default_form do
    %{
      "principal" => "",
      "extra" => "",
      "rate" => "",
      "rate_period" => "month",
      "duration" => "",
      "duration_unit" => "month",
      "method" => "price"
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
                  {gettext("Loan simulator")}
                </h1>
                <p class="text-sm text-base-content/70 max-w-xl">
                  {gettext("Compare Price and SAC: see first/last installment, totals and full amortization tables for each method.")}
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
            as={:loan}
            phx-change="change"
            class="bg-base-100 border border-base-300 rounded-2xl p-5 space-y-4 lg:col-span-1 shadow-sm"
          >
            <div class="space-y-1" phx-update="ignore" id="loan-principal-input-container">
              <label class="text-sm font-medium" for="loan_principal_input">{gettext("Loan amount")}</label>
              <input
                id="loan_principal_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="loan[principal]"
              />
              <input
                type="hidden"
                name="loan[principal]"
                value={@form_data["principal"]}
              />
            </div>

            <div class="space-y-1" phx-update="ignore" id="loan-extra-input-container">
              <label class="text-sm font-medium" for="loan_extra_input">{gettext("Extra amortization (monthly, optional)")}</label>
              <input
                id="loan_extra_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="loan[extra]"
              />
              <input
                type="hidden"
                name="loan[extra]"
                value={@form_data["extra"] || ""}
              />
              <p class="text-xs text-base-content/70">{gettext("Applied every month after the regular payment.")}</p>
              <%= if @extra_warning do %>
                <p class="text-xs text-warning mt-1">{@extra_warning}</p>
              <% end %>
            </div>

            <.input
              name="loan[rate]"
              type="number"
              label={gettext("Interest rate (%)")}
              value={@form_data["rate"]}
              min="0"
              step="0.01"
            />

            <.input
              type="select"
              name="loan[rate_period]"
              label={gettext("Rate period")}
              value={@form_data["rate_period"]}
              options={[
                {gettext("per month"), "month"},
                {gettext("per year"), "year"}
              ]}
            />

            <.input
              name="loan[duration]"
              type="number"
              label={gettext("Term")}
              value={@form_data["duration"]}
              min="1"
              step="1"
            />

            <.input
              type="select"
              name="loan[duration_unit]"
              label={gettext("Unit")}
              value={@form_data["duration_unit"]}
              options={[
                {gettext("months"), "month"},
                {gettext("years"), "year"}
              ]}
            />

            <.input
              type="select"
              name="loan[method]"
              label={gettext("Method")}
              value={@form_data["method"]}
              options={[
                {gettext("Price"), "price"},
                {gettext("SAC"), "sac"},
                {gettext("Compare"), "compare"}
              ]}
              option_icons={%{
                "price" => "hero-banknotes",
                "sac" => "hero-scale",
                "compare" => "hero-arrows-right-left"
              }}
              data-hint={gettext("Choose Price, SAC or compare both side by side")}
            />

          </.form>

          <%= if @result do %>
            <%= case @result.method do %>
              <% :price -> %>
                <div class="lg:col-span-2 space-y-4">
                  <.result_cards
                    result={@result.price}
                    baseline={@result.baseline}
                    compare_baseline?={@result.compare_baseline?}
                    title={gettext("Price")}
                    extra={safe_float(@form_data["extra"])}
                  />
                  <.schedule_table result={@result.price} title={gettext("Amortization schedule (Price)")} export_target="price-current" />
                </div>

              <% :sac -> %>
                <div class="lg:col-span-2 space-y-4">
                  <.result_cards
                    result={@result.sac}
                    baseline={@result.baseline}
                    compare_baseline?={@result.compare_baseline?}
                    title={gettext("SAC")}
                    extra={safe_float(@form_data["extra"])}
                  />
                  <.schedule_table result={@result.sac} title={gettext("Amortization schedule (SAC)")} export_target="sac-current" />
                </div>

              <% :compare -> %>
                <div class="lg:col-span-2 space-y-6">
                  <.result_cards_compare
                    price={@result.price}
                    sac={@result.sac}
                    baseline_price={@result.baseline_price}
                    baseline_sac={@result.baseline_sac}
                    compare_baseline?={@result.compare_baseline?}
                    extra={safe_float(@form_data["extra"])}
                  />
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <.schedule_table result={@result.price} title={gettext("Amortization schedule (Price)")} export_target="price-current" />
                    <.schedule_table result={@result.sac} title={gettext("Amortization schedule (SAC)")} export_target="sac-current" />
                  </div>
                </div>
            <% end %>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :result, :map, required: true
  attr :baseline, :map, default: nil
  attr :compare_baseline?, :boolean, default: false
  attr :title, :string, required: true
  attr :extra, :float, default: 0.0
  defp result_cards(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-2">
      <h3 class="font-semibold text-base">{@title}</h3>
      <%= if @extra > 0 do %>
        <span class="badge badge-primary badge-sm">{gettext("Extra ativo")}</span>
      <% end %>
    </div>
    <% first_payment = payment_from_row(List.first(@result.schedule)) %>
    <% last_payment = payment_from_row(List.last(@result.schedule)) %>
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
        <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          {gettext("Installment")}
        </div>
        <div class="mt-2 text-2xl font-bold text-primary">
          <%= if first_payment == last_payment do %>
            {CurrencyUtils.format_money(first_payment)}
          <% else %>
            {CurrencyUtils.format_money(first_payment)} -> {CurrencyUtils.format_money(last_payment)}
          <% end %>
        </div>
      </div>

      <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
        <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          {gettext("Total paid")}
        </div>
        <div class="mt-2 text-2xl font-bold text-base-content">
          {CurrencyUtils.format_money(@result.total_paid)}
        </div>
        <div class="text-[11px] text-base-content/60 mt-1">
          <%= if @result[:months_used] do %>
            {gettext("Months")}: {@result.months_used}
          <% end %>
        </div>
      </div>

      <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
        <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          {gettext("Total interest")}
        </div>
        <div class="mt-2 text-2xl font-bold text-error">
          {CurrencyUtils.format_money(@result.total_interest)}
        </div>
        <%= if @compare_baseline? and @baseline do %>
          <div class="text-[11px] text-success/80 mt-1">
            {gettext("Saved vs no extra")}: {CurrencyUtils.format_money(interest_saved(@baseline, @result))}
          </div>
        <% end %>
      </div>

      <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
        <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          {gettext("Extra amortization")}
        </div>
        <div class="mt-2 text-xl font-bold text-primary">
          <%= if @extra > 0 do %>
            {CurrencyUtils.format_money(@extra)} / {gettext("month")}
          <% else %>
            {gettext("Not applied")}
          <% end %>
        </div>
        <%= if @compare_baseline? and @baseline do %>
          <div class="text-[11px] text-base-content/60 mt-1">
            {gettext("Months saved")}: {months_saved(@baseline, @result)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :price, :map, required: true
  attr :sac, :map, required: true
  attr :baseline_price, :map, default: nil
  attr :baseline_sac, :map, default: nil
  attr :compare_baseline?, :boolean, default: false
  attr :extra, :float, default: 0.0
  defp result_cards_compare(assigns) do
    ~H"""
    <% price_first = payment_from_row(List.first(@price.schedule)) %>
    <% price_last = payment_from_row(List.last(@price.schedule)) %>
    <% sac_first = payment_from_row(List.first(@sac.schedule)) %>
    <% sac_last = payment_from_row(List.last(@sac.schedule)) %>

    <div class="flex items-center justify-between mb-2">
      <h3 class="font-semibold text-base">{gettext("Comparison")}</h3>
      <%= if @extra > 0 do %>
        <span class="badge badge-primary badge-sm">{gettext("Extra ativo")}</span>
      <% end %>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
        <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          {gettext("Installment")}
        </div>
        <div class="mt-2 text-2xl font-bold text-primary space-y-1">
          <div>
            <span class="text-xs text-base-content/60">Price</span><br />
            {CurrencyUtils.format_money(price_first)}
            <%= if price_last != price_first do %>
              -> {CurrencyUtils.format_money(price_last)}
            <% end %>
          </div>
          <div class="pt-1">
            <span class="text-xs text-base-content/60">SAC</span><br />
            {CurrencyUtils.format_money(sac_first)} -> {CurrencyUtils.format_money(sac_last)}
          </div>
        </div>
      </div>

      <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
        <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          {gettext("Total paid")}
        </div>
        <div class="mt-2 text-2xl font-bold text-base-content space-y-1">
          <div>
            <span class="text-xs text-base-content/60">Price</span><br />
            {CurrencyUtils.format_money(@price.total_paid)}
          </div>
          <div class="pt-1">
            <span class="text-xs text-base-content/60">SAC</span><br />
            {CurrencyUtils.format_money(@sac.total_paid)}
          </div>
        </div>
        <div class="text-[11px] text-base-content/60 mt-1">
          {gettext("Months")}: {@price.months_used} / {@sac.months_used}
        </div>
      </div>

      <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
        <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          {gettext("Total interest")}
        </div>
        <div class="mt-2 text-2xl font-bold text-error space-y-1">
          <div>
            <span class="text-xs text-base-content/60">Price</span><br />
            {CurrencyUtils.format_money(@price.total_interest)}
          </div>
          <div class="pt-1">
            <span class="text-xs text-base-content/60">SAC</span><br />
            {CurrencyUtils.format_money(@sac.total_interest)}
          </div>
        </div>
        <%= if @compare_baseline? do %>
          <div class="text-[11px] text-success/80 mt-1 space-y-1">
            <div>Price: {CurrencyUtils.format_money(interest_saved(@baseline_price, @price))}</div>
            <div>SAC: {CurrencyUtils.format_money(interest_saved(@baseline_sac, @sac))}</div>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @compare_baseline? do %>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mt-2">
        <div class="text-xs text-base-content/70 bg-base-100 border border-base-200 rounded-xl p-3">
          <div class="font-semibold text-base-content">Price</div>
          <div class="mt-1">{gettext("Months saved")}: {months_saved(@baseline_price, @price)}</div>
          <div class="mt-1">{gettext("Interest saved")}: {CurrencyUtils.format_money(interest_saved(@baseline_price, @price))}</div>
        </div>
        <div class="text-xs text-base-content/70 bg-base-100 border border-base-200 rounded-xl p-3">
          <div class="font-semibold text-base-content">SAC</div>
          <div class="mt-1">{gettext("Months saved")}: {months_saved(@baseline_sac, @sac)}</div>
          <div class="mt-1">{gettext("Interest saved")}: {CurrencyUtils.format_money(interest_saved(@baseline_sac, @sac))}</div>
        </div>
      </div>
    <% end %>
    """
  end

  attr :result, :map, required: true
  attr :title, :string, required: true
  attr :export_target, :string, required: true
  defp schedule_table(assigns) do
    ~H"""
    <% csv_data = schedule_to_csv(@result.schedule) %>
    <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
      <div class="flex items-center justify-between mb-3">
        <h3 class="font-semibold text-base">{@title}</h3>
        <a class="btn btn-ghost btn-xs"
           download={"#{@export_target}.csv"}
           href={"data:text/csv;charset=utf-8," <> URI.encode(csv_data)}>
          <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
          <span class="ml-1 text-xs">CSV</span>
        </a>
      </div>
      <div class="overflow-x-auto overflow-y-auto max-h-96">
        <table class="table table-sm">
          <thead>
            <tr>
              <th class="text-xs">{gettext("Period")}</th>
              <th class="text-xs">{gettext("Payment")}</th>
              <th class="text-xs">{gettext("Interest")}</th>
              <th class="text-xs">{gettext("Amortization")}</th>
              <th class="text-xs">{gettext("Balance")}</th>
            </tr>
          </thead>
          <tbody>
            <%= for row <- @result.schedule do %>
              <tr>
                <td class="text-xs">{row.period}</td>
                <td class="text-xs">{CurrencyUtils.format_money(row.payment)}</td>
                <td class="text-xs">{CurrencyUtils.format_money(row.interest)}</td>
                <td class="text-xs">{CurrencyUtils.format_money(row.amortization)}</td>
                <td class="text-xs">{CurrencyUtils.format_money(row.balance)}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp payment_from_row(nil), do: 0.0
  defp payment_from_row(%{payment: payment}) when is_number(payment), do: payment
  defp payment_from_row(_), do: 0.0

  defp interest_saved(nil, _current), do: 0.0
  defp interest_saved(%{total_interest: base_interest}, %{total_interest: current_interest}) do
    max(base_interest - current_interest, 0.0)
  end
  defp interest_saved(_, _), do: 0.0

  defp months_saved(nil, _current), do: 0
  defp months_saved(%{months_used: base_months}, %{months_used: current_months}) do
    max(base_months - current_months, 0)
  end
  defp months_saved(_, _), do: 0

  defp schedule_to_csv(rows) do
    data = [["period", "payment", "interest", "amortization", "balance"] | Enum.map(rows, &schedule_row_to_list/1)]
    data
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp schedule_row_to_list(%{period: p, payment: pay, interest: int, amortization: am, balance: bal}) do
    [p, format_csv_float(pay), format_csv_float(int), format_csv_float(am), format_csv_float(bal)]
  end

  defp format_csv_float(value) when is_number(value), do: :erlang.float_to_binary(value, [:compact, {:decimals, 2}])
  defp format_csv_float(value), do: to_string(value)
end
