defmodule PersonalFinanceWeb.PlaygroundLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance

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
      {:ok, assign(socket, page_title: "Playground - #{ledger.name}", ledger: ledger)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} show_sidebar={true} ledger={@ledger}>
      <div class="min-h-screen pb-12 space-y-6">
        <section class="bg-base-100/80 border border-base-300 rounded-2xl p-6 shadow-sm mt-4">
          <div class="space-y-2">
            <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
              Playground
            </p>
            <div class="space-y-1">
              <h1 class="text-xl font-bold text-base-content">
                {gettext("Financial math tools")}
              </h1>
              <p class="text-sm text-base-content/70">
                {gettext("Simulate investments, debts and financial plans for this ledger.")}
              </p>
            </div>
          </div>
        </section>

            <section class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.link
                navigate={~p"/ledgers/#{@ledger.id}/playground/interest"}
                class="card bg-base-100 border border-base-300 hover:border-primary/80 hover:shadow-md transition-colors cursor-pointer p-5 flex flex-col gap-3 rounded-2xl"
              >
                <div class="flex items-center justify-between gap-3">
                  <div class="flex items-center gap-2">
                    <div class="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary">
                      <.icon name="hero-chart-bar" class="w-5 h-5" />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-base-content">
                        {gettext("Interest simulator")}
                      </p>
                      <p class="text-xs text-base-content/70">
                        {gettext("Simple and compound interest with optional monthly contributions.")}
                      </p>
                    </div>
                  </div>
                </div>
              </.link>

              <.link
                navigate={~p"/ledgers/#{@ledger.id}/playground/goal"}
                class="card bg-base-100 border border-base-300 hover:border-primary/80 hover:shadow-md transition-colors cursor-pointer p-5 flex flex-col gap-3 rounded-2xl"
              >
                <div class="flex items-center justify-between gap-3">
                  <div class="flex items-center gap-2">
                    <div class="w-10 h-10 rounded-full bg-success/10 flex items-center justify-center text-success">
                      <.icon name="hero-flag" class="w-5 h-5" />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-base-content">
                        {gettext("Rate calculator")}
                      </p>
                      <p class="text-xs text-base-content/70">
                        {gettext("Calculate the required rate of return to reach your financial goal.")}
                      </p>
                    </div>
                  </div>
                </div>
              </.link>

              <.link
                navigate={~p"/ledgers/#{@ledger.id}/playground/contribution"}
                class="card bg-base-100 border border-base-300 hover:border-primary/80 hover:shadow-md transition-colors cursor-pointer p-5 flex flex-col gap-3 rounded-2xl"
              >
                <div class="flex items-center justify-between gap-3">
                  <div class="flex items-center gap-2">
                    <div class="w-10 h-10 rounded-full bg-info/10 flex items-center justify-center text-info">
                      <.icon name="hero-calculator" class="w-5 h-5" />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-base-content">
                        {gettext("Contribution calculator")}
                      </p>
                      <p class="text-xs text-base-content/70">
                        {gettext("Calculate how much you need to contribute monthly to reach your goal.")}
                      </p>
                    </div>
                  </div>
                </div>
              </.link>

              <.link
                navigate={~p"/ledgers/#{@ledger.id}/playground/loan"}
                class="card bg-base-100 border border-base-300 hover:border-primary/80 hover:shadow-md transition-colors cursor-pointer p-5 flex flex-col gap-3 rounded-2xl"
              >
                <div class="flex items-center justify-between gap-3">
                  <div class="flex items-center gap-2">
                    <div class="w-10 h-10 rounded-full bg-warning/10 flex items-center justify-center text-warning">
                      <.icon name="hero-banknotes" class="w-5 h-5" />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-base-content">
                        {gettext("Loan simulator")}
                      </p>
                      <p class="text-xs text-base-content/70">
                        {gettext("Calculate installment, total paid and interest for a loan.")}
                      </p>
                    </div>
                  </div>
                </div>
              </.link>

              <.link
                navigate={~p"/ledgers/#{@ledger.id}/playground/debt_compare"}
                class="card bg-base-100 border border-base-300 hover:border-primary/80 hover:shadow-md transition-colors cursor-pointer p-5 flex flex-col gap-3 rounded-2xl"
              >
                <div class="flex items-center justify-between gap-3">
                  <div class="flex items-center gap-2">
                    <div class="w-10 h-10 rounded-full bg-error/10 flex items-center justify-center text-error">
                      <.icon name="hero-scale" class="w-5 h-5" />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-base-content">
                        {gettext("Finance or pay upfront?")}
                      </p>
                      <p class="text-xs text-base-content/70">
                        {gettext("Compare financing with installments vs paying upfront with discount.")}
                      </p>
                    </div>
                  </div>
                </div>
              </.link>

              <.link
                navigate={~p"/ledgers/#{@ledger.id}/playground/fi"}
                class="card bg-base-100 border border-base-300 hover:border-primary/80 hover:shadow-md transition-colors cursor-pointer p-5 flex flex-col gap-3 rounded-2xl"
              >
                <div class="flex items-center justify-between gap-3">
                  <div class="flex items-center gap-2">
                    <div class="w-10 h-10 rounded-full bg-purple-500/10 flex items-center justify-center text-purple-500">
                      <.icon name="hero-fire" class="w-5 h-5" />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-base-content">
                        {gettext("Financial Independence (FI)")}
                      </p>
                      <p class="text-xs text-base-content/70">
                        {gettext("Calculate wealth needed for FI and time to reach it.")}
                      </p>
                    </div>
                  </div>
                </div>
              </.link>
            </section>
          </div>
        </Layouts.app>
    """
  end
end
