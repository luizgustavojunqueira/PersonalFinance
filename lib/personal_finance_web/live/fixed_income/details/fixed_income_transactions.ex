defmodule PersonalFinanceWeb.FixedIncomeLive.Details.FixedIncomeTransactions do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Investment
  alias PersonalFinance.Utils.CurrencyUtils
  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinanceWeb.Components.InfiniteScroll

  @default_page_size 50

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :page_size, @default_page_size)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:page_size, fn -> @default_page_size end)
      |> assign(:scroll_id, build_scroll_id(assigns, socket))

    {:ok, handle_action(assigns, socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.live_component
        module={InfiniteScroll}
        id={@scroll_id}
        stream_name="transaction_collection"
        loader_mfa={{__MODULE__, :fetch_transactions, [@fixed_income]}}
        per_page={@page_size}
        wrapper_class="space-y-4"
      >
        <:content :let={transactions_stream}>
          <div class="rounded-2xl border border-base-300 bg-base-100/80 shadow-sm">
            <.table
              id="fixed_income_transactions_table"
              rows={transactions_stream}
              col_widths={["15%", "25%", "20%", "20%", "20%"]}
              row_item={
                fn
                  {_, struct} -> struct
                  struct -> struct
                end
              }
            >
              <:col :let={transaction} label={gettext("Date")}>
                {DateUtils.format_date(transaction.date, :with_time)}
              </:col>
              <:col :let={transaction} label={gettext("Description")}>
                <.text_ellipsis text={transaction.description} max_width="max-w-[15rem]" />
              </:col>
              <:col :let={transaction} label={gettext("Gross Value")}>
                <span class={[
                  "font-semibold",
                  transaction.type in [:deposit, :yield] && "text-success",
                  transaction.type not in [:deposit, :yield] && "text-error"
                ]}>
                  {CurrencyUtils.format_money(Decimal.to_float(transaction.value))}
                </span>
              </:col>

              <:col :let={transaction} label={gettext("IR")}>
                <span class={[
                  "font-semibold",
                  transaction.type == :yield && "text-error"
                ]}>
                  <%= if transaction.tax == nil or Decimal.equal?(transaction.tax, 0) do %>
                    -
                  <% else %>
                    {CurrencyUtils.format_money(Decimal.to_float(transaction.tax))}
                  <% end %>
                </span>
              </:col>
              <:col :let={transaction} label={gettext("Net Value")}>
                <span class={[
                  "font-semibold",
                  transaction.type in [:deposit, :yield] && "text-success",
                  transaction.type not in [:deposit, :yield] && "text-error"
                ]}>
                  <%= if transaction.tax == nil or Decimal.equal?(transaction.tax, 0) do %>
                    {CurrencyUtils.format_money(Decimal.to_float(transaction.value))}
                  <% else %>
                    {CurrencyUtils.format_money(
                      Decimal.to_float(Decimal.sub(transaction.value, transaction.tax))
                    )}
                  <% end %>
                </span>
              </:col>
            </.table>
          </div>
        </:content>
        <:empty>
          <div class="rounded-2xl border border-dashed border-base-300 bg-base-100/70 p-8 text-center text-sm text-base-content/70">
            {gettext("No transactions found.")}
          </div>
        </:empty>
      </.live_component>
    </div>
    """
  end

  def handle_action(%{action: :saved, fixed_income_transaction: transaction}, socket) do
    send_update(InfiniteScroll,
      id: socket.assigns.scroll_id,
      action: :insert_new_item,
      item: transaction
    )

    socket
  end

  def handle_action(_assigns, socket), do: socket

  def fetch_transactions(fixed_income, opts) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, @default_page_size)

    page_data = Investment.list_transactions(fixed_income, page, per_page)

    %{
      items: page_data.entries,
      total_items: page_data.total_entries,
      items_in_page: length(page_data.entries),
      total_pages: page_data.total_pages
    }
  end

  defp build_scroll_id(assigns, socket) do
    base_id =
      case {Map.get(assigns, :id), Map.get(socket.assigns, :id)} do
        {id, _} when is_binary(id) and id != "" -> id
        {_, id} when is_binary(id) and id != "" -> id
        _ -> "fixed-income-transactions"
      end

    base_id
    |> to_string()
    |> Kernel.<>("-scroll")
  end
end
