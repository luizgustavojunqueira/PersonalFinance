defmodule PersonalFinanceWeb.LedgersLive.LedgerCardItem do
  use PersonalFinanceWeb, :live_component
  alias PersonalFinance.Utils.CurrencyUtils

  @impl true
  def mount(socket) do
    {:ok, assign(socket, show_values: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="group card bg-base-100 shadow-md hover:shadow-xl transition-all duration-300 border border-base-300 hover:border-primary/30 overflow-hidden"
      id={@id}
      phx-mounted={JS.transition({"ease-out duration-500", "opacity-0 translate-y-4", "opacity-100 translate-y-0"}, time: 500)}
    >
      <div class="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-primary via-secondary to-accent"></div>

      <div class="card-body p-5">
        <div class="flex items-start justify-between mb-2">
          <div class="flex items-center gap-2 flex-1 min-w-0">
            <div class={
              "avatar placeholder " <>
              if(@is_owner, do: "bg-primary/10", else: "bg-secondary/10")
            }>
              <div class="w-10 h-10 rounded-lg flex items-center justify-center">
                <.icon
                  name={if @is_owner, do: "hero-briefcase", else: "hero-user-group"}
                  class={
                    "w-5 h-5 " <>
                    if(@is_owner, do: "text-primary", else: "text-secondary")
                  }
                />
              </div>
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <h3 class="font-bold text-base text-base-content truncate">
                  {@ledger.name}
                </h3>
                <button
                  phx-click="toggle_visibility"
                  phx-target={@myself}
                  class="btn btn-ghost btn-xs btn-circle opacity-60 hover:opacity-100 transition-opacity"
                  title={if @show_values, do: gettext("Hide values"), else: gettext("Show values")}
                >
                  <.icon
                    name={if @show_values, do: "hero-eye", else: "hero-eye-slash"}
                    class="w-4 h-4 transition-transform duration-300"
                  />
                </button>
              </div>
              <p class="text-xs text-base-content/50">
                <%= if @is_owner do %>
                  <.icon name="hero-user" class="w-3 h-3 inline" /> <%= gettext("Owner") %>
                <% else %>
                  <.icon name="hero-share" class="w-3 h-3 inline" /> {@ledger.owner.name}
                <% end %>
              </p>
            </div>
          </div>

          <%= if @is_owner do %>
            <div class="dropdown dropdown-end">
              <label tabindex="0" class="btn btn-ghost btn-xs btn-square opacity-60 hover:opacity-100">
                <.icon name="hero-ellipsis-vertical" class="w-4 h-4" />
              </label>
              <ul tabindex="0" class="dropdown-content menu w-52 rounded-box bg-base-100 shadow-xl border border-base-300 p-2 z-10">
                <li>
                  <.link patch={~p"/ledgers/#{@ledger.id}/edit"} class="flex items-center gap-2 hover:bg-primary/10">
                    <.icon name="hero-pencil" class="w-4 h-4" />
                    <span><%= gettext("Edit") %></span>
                  </.link>
                </li>
                <li>
                  <.link patch={~p"/ledgers/#{@ledger.id}/delete"} class="flex items-center gap-2 hover:bg-error/10 text-error">
                    <.icon name="hero-trash" class="w-4 h-4" />
                    <span><%= gettext("Delete") %></span>
                  </.link>
                </li>
              </ul>
            </div>
          <% end %>
        </div>

        <%= if Map.has_key?(@ledger, :stats) do %>
          <div class="bg-base-200/50 rounded-lg p-3 space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-xs font-medium text-base-content/60 flex items-center gap-1">
                <.icon name="hero-banknotes" class="w-3.5 h-3.5" />
                <%= gettext("Total Balance") %>
              </span>
              <span
                class={[
                  "text-sm font-bold transition-all duration-300",
                  if(@ledger.stats.balance >= 0, do: "text-success", else: "text-error")
                ]}
                phx-mounted={
                  if(@show_values,
                    do: JS.transition({"ease-out duration-300", "opacity-0 scale-95", "opacity-100 scale-100"}),
                    else: ""
                  )
                }
              >
                <%= if @show_values do %>
                  {CurrencyUtils.format_money(@ledger.stats.balance)}
                <% else %>
                  <span class="tracking-wider">•••••</span>
                <% end %>
              </span>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-xs font-medium text-base-content/60 flex items-center gap-1">
                <.icon name="hero-calendar" class="w-3.5 h-3.5" />
                <%= gettext("This Month") %>
              </span>
              <span
                class={[
                  "text-sm font-semibold transition-all duration-300",
                  if(@ledger.stats.month_balance >= 0, do: "text-success", else: "text-error")
                ]}
              >
                <%= if @show_values do %>
                  {CurrencyUtils.format_money(@ledger.stats.month_balance)}
                <% else %>
                  <span class="tracking-wider">•••••</span>
                <% end %>
              </span>
            </div>

            <div class="flex items-center justify-between pt-1 border-t border-base-300">
              <span class="text-xs font-medium text-base-content/60 flex items-center gap-1">
                <.icon name="hero-list-bullet" class="w-3.5 h-3.5" />
                <%= gettext("Transactions") %>
              </span>
              <span class="text-sm font-semibold text-base-content transition-all duration-300">
                <%= if @show_values do %>
                  {@ledger.stats.transaction_count}
                <% else %>
                  <span class="tracking-wider">•••</span>
                <% end %>
              </span>
            </div>
          </div>
        <% end %>

        <button
          class="btn btn-primary btn-sm w-full mt-3 gap-2"
          phx-click="view_ledger"
          phx-value-ledger-id={@ledger.id}
          phx-target={@myself}
        >
          <%= gettext("Open Ledger") %>
          <.icon name="hero-arrow-right" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("view_ledger", %{"ledger-id" => ledger_id}, socket) do
    {:noreply, Phoenix.LiveView.push_navigate(socket, to: ~p"/ledgers/#{ledger_id}/home")}
  end

  @impl true
  def handle_event("toggle_visibility", _params, socket) do
    {:noreply, assign(socket, show_values: !socket.assigns.show_values)}
  end
end
