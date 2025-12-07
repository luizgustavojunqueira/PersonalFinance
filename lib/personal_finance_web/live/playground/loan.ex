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
         result: nil
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

    method = normalize_method(params["method"])

    should_calculate = principal > 0 and rate > 0 and duration > 0

    result =
      if should_calculate do
        mapped_params = %{
          principal: principal,
          rate: rate,
          rate_period: normalize_rate_period(params["rate_period"]),
          duration: duration,
          duration_unit: normalize_duration_unit(params["duration_unit"])
        }

        case method do
          :price -> %{method: :price, price: Loans.price_amortization(mapped_params)}
          :sac -> %{method: :sac, sac: Loans.sac_amortization(mapped_params)}
          :compare -> %{
            method: :compare,
            price: Loans.price_amortization(mapped_params),
            sac: Loans.sac_amortization(mapped_params)
          }
        end
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
                  <.result_cards result={@result.price} title={gettext("Price")} />
                  <.schedule_table result={@result.price} title={gettext("Amortization schedule (Price)")} />
                </div>

              <% :sac -> %>
                <div class="lg:col-span-2 space-y-4">
                  <.result_cards result={@result.sac} title={gettext("SAC")} />
                  <.schedule_table result={@result.sac} title={gettext("Amortization schedule (SAC)")} />
                </div>

              <% :compare -> %>
                <div class="lg:col-span-2 space-y-6">
                  <.result_cards_compare price={@result.price} sac={@result.sac} />
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <.schedule_table result={@result.price} title={gettext("Amortization schedule (Price)")} />
                    <.schedule_table result={@result.sac} title={gettext("Amortization schedule (SAC)")} />
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
  attr :title, :string, required: true
  defp result_cards(assigns) do
    ~H"""
    <% first_payment = payment_from_row(List.first(@result.schedule)) %>
    <% last_payment = payment_from_row(List.last(@result.schedule)) %>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
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
      </div>

      <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
        <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          {gettext("Total interest")}
        </div>
        <div class="mt-2 text-2xl font-bold text-error">
          {CurrencyUtils.format_money(@result.total_interest)}
        </div>
      </div>
    </div>
    """
  end

  attr :price, :map, required: true
  attr :sac, :map, required: true
  defp result_cards_compare(assigns) do
    ~H"""
    <% price_first = payment_from_row(List.first(@price.schedule)) %>
    <% price_last = payment_from_row(List.last(@price.schedule)) %>
    <% sac_first = payment_from_row(List.first(@sac.schedule)) %>
    <% sac_last = payment_from_row(List.last(@sac.schedule)) %>

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
      </div>
    </div>
    """
  end

  attr :result, :map, required: true
  attr :title, :string, required: true
  defp schedule_table(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
      <h3 class="font-semibold text-base mb-3">{@title}</h3>
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
end
