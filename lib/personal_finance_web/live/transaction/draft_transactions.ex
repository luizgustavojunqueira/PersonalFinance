defmodule PersonalFinanceWeb.TransactionLive.DraftTransactions do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Utils.{CurrencyUtils, DateUtils}
  alias PersonalFinance.Finance

  @impl true
  def update(assigns, socket) do
    ledger = Map.fetch!(assigns, :ledger)
    current_scope = Map.fetch!(assigns, :current_scope)

    drafts = load_drafts(current_scope, ledger)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(drafts: drafts)}
  end

  defp load_drafts(scope, ledger) do
    %{entries: entries} = Finance.list_transactions(scope, ledger, %{draft: true}, 1, :all)
    entries
  end

  @impl true
  def handle_event("confirm_draft", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger

    transaction = Finance.get_transaction(current_scope, id, ledger)

    case Finance.update_transaction_draft(current_scope, transaction, false) do
      {:ok, updated} ->
        send(socket.assigns.parent_pid, {:saved, updated})
        {:noreply, socket}

      {:error, _changeset} ->
        send(socket.assigns.parent_pid, {:put_flash, :error, gettext("Error confirming draft.")})
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_draft", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope
    ledger = socket.assigns.ledger

    transaction = Finance.get_transaction(current_scope, id, ledger)

    case Finance.delete_transaction(current_scope, transaction) do
      {:ok, deleted} ->
        send(socket.assigns.parent_pid, {:deleted, deleted})
        drafts = load_drafts(current_scope, ledger)
        {:noreply, assign(socket, drafts: drafts)}

      {:error, _reason} ->
        send(socket.assigns.parent_pid, {:put_flash, :error, gettext("Error deleting draft.")})
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_draft", %{"id" => id}, socket) do
    send(socket.assigns.parent_pid, {:open_edit_transaction, id})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.side_modal
        id="draft_transactions_modal"
        show={@show}
        on_close={JS.push("close_draft_modal")}
      >
        <:title>
          <div class="space-y-1">
            <p class="text-base-content font-semibold">{gettext("Draft Transactions")}</p>
            <p class="text-sm text-base-content/70">{gettext("Transactions saved as draft (not in balance)")}</p>
          </div>
        </:title>

        <div class="space-y-4">
          <div class="flex-grow overflow-y-auto rounded-2xl border border-base-300 bg-base-100/80 p-4">
            <%= if @drafts == [] do %>
              <div class="text-center text-base-content/60">
                <.icon name="hero-check-circle" class="w-8 h-8 mx-auto text-success" />
                <p class="mt-2 font-medium">{gettext("No draft transactions.")}</p>
              </div>
            <% else %>
              <.table id="draft_transactions_table" rows={@drafts}>
                <:col :let={transaction} label={gettext("Date")}>
                  <%= if transaction.date do %>
                    {DateUtils.to_local_time_with_date(transaction.date) |> DateUtils.format_date()}
                  <% else %>
                    {gettext("N/A")}
                  <% end %>
                </:col>
                <:col :let={transaction} label={gettext("Description")}>
                  {transaction.description}
                </:col>
                <:col :let={transaction} label={gettext("Profile")}>
                  {transaction.profile && transaction.profile.name}
                </:col>
                <:col :let={transaction} label={gettext("Category")}>
                  {transaction.category && transaction.category.name}
                </:col>
                <:col :let={transaction} label={gettext("Total Value")}>
                  {CurrencyUtils.format_money(transaction.total_value)}
                </:col>
                <:action :let={transaction}>
                  <div class="flex gap-2 justify-end">
                    <.button
                      variant="custom"
                      size="xs"
                      class="btn-outline"
                      phx-click="edit_draft"
                      phx-value-id={transaction.id}
                      phx-target={@myself}
                    >
                      <.icon name="hero-pencil" class="w-4 h-4" />
                    </.button>
                    <.button
                      variant="primary"
                      size="xs"
                      phx-click="confirm_draft"
                      phx-value-id={transaction.id}
                      phx-target={@myself}
                    >
                      <.icon name="hero-check" class="w-4 h-4" />
                      {gettext("Confirm")}
                    </.button>
                    <.button
                      variant="custom"
                      size="xs"
                      class="btn-outline text-red-500"
                      phx-click="delete_draft"
                      phx-value-id={transaction.id}
                      phx-target={@myself}
                    >
                      <.icon name="hero-trash" class="w-4 h-4" />
                    </.button>
                  </div>
                </:action>
              </.table>
            <% end %>
          </div>
        </div>
      </.side_modal>
    </div>
    """
  end
end
