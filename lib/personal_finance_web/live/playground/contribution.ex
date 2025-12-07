defmodule PersonalFinanceWeb.PlaygroundLive.Contribution do
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
         page_title: gettext("Contribution calculator") <> " - #{ledger.name}",
         form_data: default_form(),
         result: nil
       )}
    end
  end

  @impl true
  def handle_event("change", %{"contribution" => params}, socket) do
    socket = assign(socket, form_data: params)

    {:noreply, run_calculation(socket)}
  end

  defp run_calculation(socket) do
    params = socket.assigns.form_data

    target = safe_float(params["target"])
    principal = safe_float(params["principal"])
    rate = safe_float(params["rate"])
    duration = safe_int(params["duration"])

    valid_target = target > 0 and target > principal
    valid_rate = rate > 0
    valid_duration = duration > 0

    should_calculate = valid_target and valid_rate and valid_duration

    result = if should_calculate do
      mapped_params = %{
        target: target,
        principal: principal,
        rate: rate,
        rate_period: normalize_rate_period(params["rate_period"]),
        duration: duration,
        duration_unit: normalize_duration_unit(params["duration_unit"])
      }

      Investments.calculate_required_contribution(mapped_params)
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

  defp default_form do
    %{
      "target" => "",
      "principal" => "0",
      "rate" => "",
      "rate_period" => "month",
      "duration" => "10",
      "duration_unit" => "year"
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
                  {gettext("Contribution calculator")}
                </h1>
                <p class="text-sm text-base-content/70 max-w-xl">
                  {gettext("Calculate how much you need to contribute monthly to reach your goal.")}
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
            as={:contribution}
            phx-change="change"
            class="bg-base-100 border border-base-300 rounded-2xl p-5 space-y-4 lg:col-span-1 shadow-sm"
          >
            <div class="space-y-1" phx-update="ignore" id="contrib-target-input-container">
              <label class="text-sm font-medium" for="contrib_target_input">{gettext("Target amount")}</label>
              <input
                id="contrib_target_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="contribution[target]"
              />
              <input
                type="hidden"
                name="contribution[target]"
                value={@form_data["target"]}
              />
            </div>

            <div class="space-y-1" phx-update="ignore" id="contrib-principal-input-container">
              <label class="text-sm font-medium" for="contrib_principal_input">{gettext("Initial amount")}</label>
              <input
                id="contrib_principal_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="contribution[principal]"
              />
              <input
                type="hidden"
                name="contribution[principal]"
                value={@form_data["principal"]}
              />
            </div>

            <.input
              name="contribution[rate]"
              type="number"
              label={gettext("Expected return rate (%)")}
              value={@form_data["rate"]}
              min="0"
              step="0.01"
            />

            <.input
              type="select"
              name="contribution[rate_period]"
              label={gettext("Rate period")}
              value={@form_data["rate_period"]}
              options={[
                {gettext("per month"), "month"},
                {gettext("per year"), "year"}
              ]}
            />

            <.input
              name="contribution[duration]"
              type="number"
              label={gettext("Time period")}
              value={@form_data["duration"]}
              min="1"
              step="1"
            />

            <.input
              type="select"
              name="contribution[duration_unit]"
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
              <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                  {gettext("Required monthly contribution")}
                </div>
                <div class="mt-2 text-3xl font-bold text-primary">
                  {CurrencyUtils.format_money(@result)}
                </div>
                <p class="text-xs text-base-content/60 mt-1">
                  {gettext("per month")}
                </p>
              </div>

              <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                <h3 class="font-semibold text-base mb-2">{gettext("Summary")}</h3>
                <div class="text-sm text-base-content/80 space-y-1">
                  <p>
                    {gettext("To reach")} <span class="font-semibold">{CurrencyUtils.format_money(safe_float(@form_data["target"]))}</span>
                    {gettext("in")} <span class="font-semibold"><%= @form_data["duration"] %> <%= if @form_data["duration_unit"] == "year", do: gettext("years"), else: gettext("months") %></span>,
                  </p>
                  <p>
                    {gettext("starting with")} <span class="font-semibold">{CurrencyUtils.format_money(safe_float(@form_data["principal"]))}</span>
                    {gettext("and expecting an average return of")} <span class="font-semibold"><%= @form_data["rate"] %>%</span> <%= if @form_data["rate_period"] == "year", do: gettext("per year"), else: gettext("per month") %>,
                  </p>
                  <p class="pt-2 font-semibold text-primary">
                    {gettext("you need to contribute")} {CurrencyUtils.format_money(@result)} {gettext("per month")}.
                  </p>
                </div>
              </div>
            </div>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
