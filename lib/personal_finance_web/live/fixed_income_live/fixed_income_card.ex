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
      class="card bg-base-100 w-full shadow-lg hover:shadow-xl transition-all duration-200"
    >
      <div class="card-body p-4">
        <div class="relative flex items-start justify-between gap-4">
          <div>
            <h3 class="card-title text-lg font-semibold">
              {@fixed_income.name} {if not @fixed_income.is_active, do: " - Inativo"}
            </h3>
            <p class="text-sm text-gray-500">{@fixed_income.institution}</p>
          </div>
          <div class="flex items-center gap-2">
            <div
              class="rounded-lg text-white text-center w-fit px-2 py-1"
              style={"background-color: #{@fixed_income.profile && @fixed_income.profile.color}99;"}
            >
              <.text_ellipsis
                class="text-xs"
                text={@fixed_income.profile && @fixed_income.profile.name}
                max_width="max-w-[10rem]"
              />
            </div>
          </div>
        </div>

        <div class="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
          <div>
            <span class="text-gray-600 font-medium">Tipo</span>
            <div class="font-medium">
              <% type = @fixed_income.type |> Atom.to_string() |> String.upcase() %>
              <% base = @fixed_income.remuneration_basis |> Atom.to_string() |> String.upcase() %>
              {type} {if base != "", do: "(" <> base <> ")", else: ""}
            </div>
          </div>

          <div>
            <span class="text-gray-600 font-medium">Remuneração</span>
            <div class="font-medium">
              {CurrencyUtils.format_rate(@fixed_income.remuneration_rate)}
            </div>
          </div>

          <div>
            <span class="text-gray-600 font-medium">Rentabilidade</span>
            <div class="font-medium">
              {format_frequency(@fixed_income.yield_frequency)}
            </div>
          </div>

          <div>
            <span class="text-gray-600 font-medium">Início</span>
            <div class="font-medium">{DateUtils.format_date(@fixed_income.start_date)}</div>
          </div>

          <div class="col-span-2 mt-2">
            <div class="grid grid-cols-2 gap-x-4 gap-y-1">
              <div>
                <span class="text-gray-600 text-xs">Investimento inicial</span>
                <div class="font-medium text-sm">
                  {CurrencyUtils.format_money(@fixed_income.initial_investment)}
                </div>
              </div>

              <div>
                <span class="text-gray-600 text-xs">Saldo atual</span>
                <div class="font-semibold text-sm">
                  {CurrencyUtils.format_money(@fixed_income.current_balance)}
                </div>
              </div>
            </div>

            <div class="mt-2 text-xs text-gray-600">
              <% total_yield = @fixed_income.total_yield || Decimal.new("0.00") %>
              <% total_tax_deducted = @fixed_income.total_tax_deducted || Decimal.new("0.00") %>
              <% net_yield = Decimal.sub(total_yield, total_tax_deducted) %>

              <div>
                Rendimento Bruto:
                <span class={"font-medium #{if total_yield >= 0, do: "text-green-600", else: "text-red-600"} "}>
                  {CurrencyUtils.format_money(Decimal.to_float(total_yield))}
                </span>
              </div>
              <div>
                Imposto Deduzido:
                <span class="font-medium text-red-600">
                  {CurrencyUtils.format_money(Decimal.to_float(total_tax_deducted))}
                </span>
              </div>
              <div>
                Rendimento Líquido:
                <span class={"font-medium #{if net_yield >= 0, do: "text-green-600", else: "text-red-600"} "}>
                  {CurrencyUtils.format_money(Decimal.to_float(net_yield))}
                </span>
              </div>
              <%= if total_yield == 0 and total_tax_deducted == 0 do %>
                <div class="text-gray-400">Sem rendimento aparente</div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="mt-4 flex justify-end gap-2">
          <.link
            class="btn btn-secondary text-sm px-4 py-2"
            navigate={~p"/ledgers/#{@ledger.id}/fixed_income/#{@fixed_income.id}"}
          >
            Ver
          </.link>
          <.button
            variant="primary"
            class="text-sm px-4 py-2"
            phx-click="open_edit_modal"
            phx-value-id={@fixed_income.id}
            disabled={@fixed_income.is_active == false}
          >
            <.icon name="hero-pencil" /> Editar
          </.button>
        </div>
      </div>
    </div>
    """
  end

  defp format_frequency(nil), do: "N/A"

  defp format_frequency(frequency) do
    frequency
    |> case do
      :daily -> "Diária"
      :weekly -> "Semanal"
      :monthly -> "Mensal"
      :quarterly -> "Trimestral"
      :semi_annual -> "Semestral"
      :annual -> "Anual"
      _ -> "N/A"
    end
  end
end
