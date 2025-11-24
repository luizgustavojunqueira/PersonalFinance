defmodule PersonalFinanceWeb.FixedIncomeLive.FixedIncomeCard do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Utils.CurrencyUtils

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="rounded-2xl border border-base-300 bg-base-100/90 p-5 shadow-sm transition hover:shadow-md hover:border-primary/40"
    >
      <div class="flex flex-col gap-4">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div class="space-y-1">
            <p class="text-xs uppercase tracking-wide text-primary/70">
              {@fixed_income.institution}
            </p>
            <h3 class="text-xl font-semibold text-base-content">
              {@fixed_income.name}
            </h3>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <span
              class={"px-3 py-1 rounded-full text-xs font-semibold #{if @fixed_income.is_active, do: "bg-success/10 text-success", else: "bg-error/10 text-error"}"}
            >
              <%= if @fixed_income.is_active, do: gettext("Active"), else: gettext("Inactive") %>
            </span>
            <%= if profile = @fixed_income.profile do %>
              <span
                class="inline-flex items-center gap-2 rounded-full border border-base-300 px-3 py-1 text-xs"
              >
                <span class="h-2.5 w-2.5 rounded-full" style={"background-color: #{profile.color};"}></span>
                <.text_ellipsis text={profile.name} max_width="max-w-[8rem]" />
              </span>
            <% end %>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-3 text-sm">
          <div class="space-y-1">
            <p class="text-xs uppercase tracking-wide text-base-content/50">{gettext("Type")}</p>
            <div class="font-semibold text-base-content">
              <% type = @fixed_income.type |> Atom.to_string() |> String.upcase() %>
              <% base = @fixed_income.remuneration_basis |> Atom.to_string() |> String.upcase() %>
              {type} {if base != "", do: "(" <> base <> ")", else: ""}
            </div>
          </div>
          <div class="space-y-1">
            <p class="text-xs uppercase tracking-wide text-base-content/50">{gettext("Remuneration")}</p>
            <div class="font-semibold text-base-content">
              {CurrencyUtils.format_rate(@fixed_income.remuneration_rate)}
            </div>
          </div>
          <div class="space-y-1">
            <p class="text-xs uppercase tracking-wide text-base-content/50">{gettext("Yield")}</p>
            <div class="font-semibold text-base-content">
              {format_frequency(@fixed_income.yield_frequency)}
            </div>
          </div>
          <div class="space-y-1">
            <p class="text-xs uppercase tracking-wide text-base-content/50">{gettext("Start")}</p>
            <div class="font-semibold text-base-content">
              {DateUtils.format_date(@fixed_income.start_date)}
            </div>
          </div>
        </div>

        <div class="rounded-xl bg-base-200/70 p-4 text-sm">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <p class="text-xs uppercase tracking-wide text-base-content/50">{gettext("Initial investment")}</p>
              <p class="font-semibold">
                {CurrencyUtils.format_money(@fixed_income.initial_investment)}
              </p>
            </div>
            <div>
              <p class="text-xs uppercase tracking-wide text-base-content/50">{gettext("Current balance")}</p>
              <p class="font-semibold">
                {CurrencyUtils.format_money(@fixed_income.current_balance)}
              </p>
            </div>
          </div>

          <% total_yield = @fixed_income.total_yield || Decimal.new("0.00") %>
          <% total_tax_deducted = @fixed_income.total_tax_deducted || Decimal.new("0.00") %>
          <% net_yield = Decimal.sub(total_yield, total_tax_deducted) %>

          <div class="mt-4 grid gap-2 text-xs sm:grid-cols-3">
            <div>
              <p class="text-base-content/50">{gettext("Gross yield")}</p>
              <p class={[
                "font-semibold",
                total_yield >= 0 && "text-success",
                total_yield < 0 && "text-error"
              ]}>
                {CurrencyUtils.format_money(Decimal.to_float(total_yield))}
              </p>
            </div>
            <div>
              <p class="text-base-content/50">{gettext("Tax deducted")}</p>
              <p class="font-semibold text-error">
                {CurrencyUtils.format_money(Decimal.to_float(total_tax_deducted))}
              </p>
            </div>
            <div>
              <p class="text-base-content/50">{gettext("Net yield")}</p>
              <p class={[
                "font-semibold",
                net_yield >= 0 && "text-success",
                net_yield < 0 && "text-error"
              ]}>
                {CurrencyUtils.format_money(Decimal.to_float(net_yield))}
              </p>
            </div>
          </div>
          <%= if total_yield == 0 and total_tax_deducted == 0 do %>
            <p class="mt-2 text-xs text-base-content/50">
              {gettext("No apparent yield yet")}
            </p>
          <% end %>
        </div>

        <div class="flex flex-wrap items-center justify-between gap-3 pt-2">
          <.link
            class="text-sm font-medium text-primary hover:underline"
            navigate={~p"/ledgers/#{@ledger.id}/fixed_income/#{@fixed_income.id}"}
          >
            <%= gettext("View details") %>
          </.link>
          <.button
            variant="primary"
            size="sm"
            class="px-4"
            phx-click="open_edit_modal"
            phx-value-id={@fixed_income.id}
            disabled={@fixed_income.is_active == false}
          >
            <.icon name="hero-pencil" /> <%= gettext("Edit") %>
          </.button>
        </div>
      </div>
    </div>
    """
  end

  defp format_frequency(nil), do: gettext("N/A")

  defp format_frequency(frequency) do
    frequency
    |> case do
      :daily -> gettext("Daily")
      :weekly -> gettext("Weekly")
      :monthly -> gettext("Monthly")
      :quarterly -> gettext("Quarterly")
      :semi_annual -> gettext("Semiannual")
      :annual -> gettext("Annual")
      _ -> gettext("N/A")
    end
  end
end
