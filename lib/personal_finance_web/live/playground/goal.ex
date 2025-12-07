defmodule PersonalFinanceWeb.PlaygroundLive.Goal do
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
         page_title: gettext("Rate calculator") <> " - #{ledger.name}",
         form_data: default_form(),
         result: nil
       )}
    end
  end

  @impl true
  def handle_event("change", %{"goal" => params}, socket) do
    socket = assign(socket, form_data: params)

    {:noreply, run_calculation(socket)}
  end

  defp run_calculation(socket) do
    params = socket.assigns.form_data

    target = safe_float(params["target"])
    principal = safe_float(params["principal"])
    monthly_contribution = safe_float(params["monthly_contribution"])
    duration = safe_int(params["duration"])

    has_investment = principal > 0 or monthly_contribution > 0
    valid_target = target > 0 and target > principal
    valid_duration = duration > 0

    should_calculate = valid_target and valid_duration and has_investment

    result = if should_calculate do
      mapped_params = %{
        target: target,
        principal: principal,
        monthly_contribution: monthly_contribution,
        duration: duration,
        duration_unit: normalize_duration_unit(params["duration_unit"])
      }

      Investments.calculate_required_rate(mapped_params)
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

  defp normalize_duration_unit("year"), do: :year
  defp normalize_duration_unit(_), do: :month

  defp default_form do
    %{
      "target" => "",
      "principal" => "0",
      "monthly_contribution" => "0",
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
                  {gettext("Rate calculator")}
                </h1>
                <p class="text-sm text-base-content/70 max-w-xl">
                  {gettext("Calculate the rate of return you need to reach your financial goal.")}
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
            as={:goal}
            phx-change="change"
            class="bg-base-100 border border-base-300 rounded-2xl p-5 space-y-4 lg:col-span-1 shadow-sm"
          >
            <div class="space-y-1" phx-update="ignore" id="target-input-container">
              <label class="text-sm font-medium" for="target_input">{gettext("Target amount")}</label>
              <input
                id="target_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="goal[target]"
              />
              <input
                type="hidden"
                name="goal[target]"
                value={@form_data["target"]}
              />
            </div>

            <div class="space-y-1" phx-update="ignore" id="goal-principal-input-container">
              <label class="text-sm font-medium" for="goal_principal_input">{gettext("Initial amount")}</label>
              <input
                id="goal_principal_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="goal[principal]"
              />
              <input
                type="hidden"
                name="goal[principal]"
                value={@form_data["principal"]}
              />
            </div>

            <div class="space-y-1" phx-update="ignore" id="goal-contribution-input-container">
              <label class="text-sm font-medium" for="goal_contribution_input">{gettext("Monthly contribution")}</label>
              <input
                id="goal_contribution_input"
                type="text"
                class="input input-bordered w-full"
                phx-hook="MoneyInput"
                data-hidden-name="goal[monthly_contribution]"
              />
              <input
                type="hidden"
                name="goal[monthly_contribution]"
                value={@form_data["monthly_contribution"]}
              />
            </div>

            <.input
              name="goal[duration]"
              type="number"
              label={gettext("Time period")}
              value={@form_data["duration"]}
              min="1"
              step="1"
            />

            <.input
              type="select"
              name="goal[duration_unit]"
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
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    {gettext("Required monthly rate")}
                  </div>
                  <div class="mt-2 text-2xl font-bold text-primary">
                    <%= Float.round(@result.monthly_rate, 2) %>%
                  </div>
                  <p class="text-xs text-base-content/60 mt-1">
                    {gettext("per month")}
                  </p>
                </div>

                <div class="card bg-base-100 border border-base-300 p-4 rounded-2xl shadow-sm">
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    {gettext("Required annual rate")}
                  </div>
                  <div class="mt-2 text-2xl font-bold text-success">
                    <%= Float.round(@result.annual_rate, 2) %>%
                  </div>
                  <p class="text-xs text-base-content/60 mt-1">
                    {gettext("per year")}
                  </p>
                </div>
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
                    {gettext("and contributing")} <span class="font-semibold">{CurrencyUtils.format_money(safe_float(@form_data["monthly_contribution"]))}</span> {gettext("per month")},
                  </p>
                  <p class="pt-2 font-semibold text-primary">
                    {gettext("you need an average return of")} <%= Float.round(@result.annual_rate, 2) %>% {gettext("per year")}.
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
