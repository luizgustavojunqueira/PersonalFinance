defmodule PersonalFinanceWeb.FixedIncomeLive.FixedIncomeCard do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Utils.CurrencyUtils
  alias PersonalFinance.Investment

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    fixed_income = assigns.fixed_income || socket.assigns.fixed_income

    socket =
      socket
      |> assign(assigns)
      |> assign(fixed_income: fixed_income)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="card bg-base-100 w-full shadow-lg">
      <div class="card-body">
        <div class="flex items-start justify-between gap-4">
          <div>
            <h3 class="card-title text-lg">{@fixed_income.name}</h3>
            <p class="text-sm text-gray-500">{@fixed_income.institution}</p>
          </div>

          <div class="flex items-center gap-2">
            <div
              class="rounded-lg text-white text-center w-fit"
              style={"background-color: #{@fixed_income.profile && @fixed_income.profile.color}99;"}
            >
              <.text_ellipsis
                class="p-1 px-2"
                text={@fixed_income.profile && @fixed_income.profile.name}
                max_width="max-w-[10rem]"
              />
            </div>
          </div>
        </div>

        <div class="mt-3 grid grid-cols-2 gap-x-2 gap-y-1 text-sm">
          <div class="space-y-1">
            <div class="text-gray-500">Tipo</div>
            <div class="font-medium">
              <% type = @fixed_income.type |> Atom.to_string() |> String.upcase() %>
              <% base =
                @fixed_income.remuneration_basis
                |> Atom.to_string()
                |> String.upcase() %>
              {type} {if base != "", do: "(" <> base <> ")", else: ""}
            </div>
          </div>

          <div class="space-y-1">
            <div class="text-gray-500">Remuneração</div>
            <div class="font-medium">
              {CurrencyUtils.format_rate(@fixed_income.remuneration_rate)}
            </div>
          </div>

          <div class="space-y-1">
            <div class="text-gray-500">Rentabilidade</div>
            <div class="font-medium">
              {format_frequency(@fixed_income.yield_frequency)}
            </div>
          </div>

          <div class="space-y-1">
            <div class="text-gray-500">Início</div>
            <div class="font-medium">{DateUtils.format_date(@fixed_income.start_date)}</div>
          </div>

          <div class="col-span-2 mt-1">
            <div class="grid grid-cols-2 items-end gap-2">
              <div>
                <div class="text-gray-500 text-xs">Investimento inicial</div>
                <div class="font-medium text-sm">
                  {CurrencyUtils.format_money(@fixed_income.initial_investment)}
                </div>
              </div>

              <div>
                <div class="text-gray-500 text-xs">Saldo atual</div>
                <div class="font-semibold text-sm">
                  {CurrencyUtils.format_money(@fixed_income.current_balance)}
                </div>
              </div>
            </div>
            <div class="mt-1">
              <div class="text-xs text-gray-600">
                <% earned =
                  case {@fixed_income.current_balance, @fixed_income.initial_investment} do
                    {c, i} when is_number(c) and is_number(i) -> c - i
                    _ -> nil
                  end %>

                <%= if earned && earned != 0 do %>
                  Rendeu:
                  <%= if earned > 0 do %>
                    <span class="font-medium text-green-600">
                      {CurrencyUtils.format_money(earned)}
                    </span>
                  <% else %>
                    <span class="font-medium text-red-600">
                      {CurrencyUtils.format_money(earned)}
                    </span>
                  <% end %>
                <% else %>
                  <span class="text-gray-400">Sem rendimento aparente</span>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <div class="card-actions justify-end mt-4">
          <div class="flex gap-2">
            <button class="btn btn-ghost btn-sm">Editar</button>
            <button class="btn btn-primary btn-sm">Ver Detalhes</button>
          </div>
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
