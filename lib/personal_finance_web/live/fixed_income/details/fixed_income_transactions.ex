defmodule PersonalFinanceWeb.FixedIncomeLive.Details.FixedIncomeTransactions do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Utils.CurrencyUtils
  alias PersonalFinance.Investment

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> stream_configure(:transaction_collection, dom_id: &"transaction-#{&1.id}")
     |> assign(:num_transactions, 0)
     |> assign(:current_page, 1)
     |> assign(:page_size, 50)
     |> assign(:total_pages, 1)}
  end

  @impl true
  def update(assigns, socket) do
    ledger = Map.get(assigns, :ledger) || socket.assigns.ledger
    fixed_income = Map.get(assigns, :fixed_income) || socket.assigns.fixed_income

    socket =
      case assigns[:action] do
        action when action in [:saved] ->
          transaction = assigns.fixed_income_transaction

          socket
          |> stream_insert(:transaction_collection, transaction, at: 0)
          |> assign(:num_transactions, socket.assigns.num_transactions + 1)

        _ ->
          page_data =
            Investment.list_transactions(
              fixed_income,
              socket.assigns.current_page,
              socket.assigns.page_size
            )

          transactions = page_data.entries

          socket
          |> assign(:num_transactions, page_data.total_entries)
          |> assign(:total_pages, page_data.total_pages)
          |> assign(:current_page, page_data.page_number)
          |> stream(:transaction_collection, transactions, reset: true)
      end

    {:ok, socket |> assign(assigns) |> assign(ledger: ledger)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <%= if @num_transactions == 0 do %>
        <p class="text-center text-gray-500"><%= gettext("No transactions found.") %></p>
      <% else %>
        <.table
          id="fixed_income_transactions_table"
          rows={@streams.transaction_collection}
          col_widths={["5%", "5%", "5%", "5%", "5%"]}
          row_item={
            fn
              {_id, struct} -> struct
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
            <span class={"font-bold #{if transaction.type in [:deposit, :yield] do "text-green-700 dark:text-green-300" else "text-red-600 dark:text-red-300" end}"}>
              {CurrencyUtils.format_money(Decimal.to_float(transaction.value))}
            </span>
          </:col>

          <:col :let={transaction} label={gettext("IR")}>
            <span class={"font-bold #{if transaction.type == :yield do "text-red-600 dark:text-red-300" else "" end}"}>
              <%= if transaction.tax == nil or Decimal.equal?(transaction.tax, 0) do %>
                -
              <% else %>
                {CurrencyUtils.format_money(Decimal.to_float(transaction.tax))}
              <% end %>
            </span>
          </:col>
          <:col :let={transaction} label={gettext("Net Value")}>
            <span class={"font-bold #{if transaction.type in [:deposit, :yield] do "text-green-700 dark:text-green-300" else "text-red-600 dark:text-red-300" end}"}>
              <%= if transaction.tax == nil or Decimal.equal?(transaction.tax, 0) do %>
                {CurrencyUtils.format_money(Decimal.to_float(transaction.value))}
              <% else %>
                {CurrencyUtils.format_money(
                  Decimal.to_float(Decimal.sub(transaction.value, transaction.tax))
                )}
              <% end %>
            </span>
          </:col>
          >
        </.table>

        <div class="mt-4 flex justify-between items-center pt-4">
          <.button
            phx-click="previous_page"
            phx-target={@myself}
            variant="custom"
            class={"btn-primary btn-outline #{if @current_page <= 1, do: "btn-disabled", else: ""}"}
          >
            <%= gettext("Previous") %>
          </.button>
          <span>
            <%= gettext("Page %{current} of %{total}", current: @current_page, total: @total_pages) %>
          </span>
          <.button
            phx-click="next_page"
            phx-target={@myself}
            variant="custom"
            class={"btn-primary btn-outline #{if @current_page >= @total_pages, do: "btn-disabled", else: ""}"}
          >
            <%= gettext("Next") %>
          </.button>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("next_page", _, socket) do
    new_page = socket.assigns.current_page + 1
    {:noreply, update_transactions(socket, new_page)}
  end

  @impl true
  def handle_event("previous_page", _, socket) do
    new_page = socket.assigns.current_page - 1
    {:noreply, update_transactions(socket, new_page)}
  end

  defp update_transactions(socket, new_page) do
    page_data =
      Investment.list_transactions(
        socket.assigns.fixed_income,
        new_page,
        socket.assigns.page_size
      )

    socket
    |> assign(:current_page, page_data.page_number)
    |> assign(:total_pages, page_data.total_pages)
    |> assign(:num_transactions, page_data.total_entries)
    |> stream(:transaction_collection, page_data.entries, reset: true)
  end

  def handle_info({:saved, fi_transaction}, socket) do
    {:noreply,
     socket
     |> assign(open_modal: nil)
     |> stream_insert(:transaction_collection, fi_transaction)
     |> put_flash(:info, gettext("Transaction successfully saved."))}
  end
end
