defmodule PersonalFinanceWeb.TransactionLive.Transactions do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.CurrencyUtils
  alias PersonalFinance.DateUtils
  alias PersonalFinance.Finance

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> stream_configure(:transaction_collection, dom_id: &"transaction-#{&1.id}")
     |> assign(:num_transactions, 0)
     |> assign(:current_page, 1)
     |> assign(:page_size, 25)
     |> assign(:total_pages, 1)}
  end

  @impl true
  def update(assigns, socket) do
    ledger = Map.get(assigns, :ledger) || socket.assigns.ledger
    current_scope = Map.get(assigns, :current_scope) || socket.assigns.current_scope
    filter_params = assigns[:filter]

    socket =
      case assigns[:action] do
        action when action in [:saved, :deleted, :update] ->
          apply_action(socket, action, assigns, filter_params)

        _ ->
          page_data =
            Finance.list_transactions(
              current_scope,
              ledger,
              filter_params || %{},
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

    {:ok, socket |> assign(assigns) |> assign(ledger: ledger, filter_params: filter_params)}
  end

  defp apply_action(socket, :saved, assigns, _) do
    transaction = assigns.transaction
    filter = socket.assigns.filter

    if transaction_matches_filters?(transaction, filter) do
      socket
      |> stream_insert(:transaction_collection, transaction, at: 0)
      |> assign(:num_transactions, socket.assigns.num_transactions + 1)
    else
      socket
    end
  end

  defp apply_action(socket, :deleted, assigns, _) do
    socket
    |> stream_delete(
      :transaction_collection,
      assigns.transaction
    )
    |> assign(num_transactions: socket.assigns.num_transactions - 1)
  end

  defp apply_action(socket, :update, _assigns, filter_params) do
    socket |> assign(filter_params: filter_params) |> update_transactions(1)
  end

  defp transaction_matches_filters?(transaction, filters) do
    Enum.all?(filters, fn
      {"category_id", id} when not is_nil(id) ->
        transaction.category_id == String.to_integer(id)

      {"profile_id", id} when not is_nil(id) ->
        transaction.profile_id == String.to_integer(id)

      {"investment_type_id", id} when not is_nil(id) ->
        transaction.investment_type_id == String.to_integer(id)

      {"type", type} when not is_nil(type) ->
        Atom.to_string(transaction.type) == type

      {"start_date", date} when not is_nil(date) ->
        transaction.date >= Date.from_iso8601!(date)

      {"end_date", date} when not is_nil(date) ->
        transaction.date <= Date.from_iso8601!(date)

      _ ->
        true
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @num_transactions == 0 do %>
        <p class="text-center text-gray-500">Nenhuma transação encontrada.</p>
      <% else %>
        <.table id="transactions_table" rows={@streams.transaction_collection}>
          <:col :let={{_id, transaction}} label="Tipo">
            <span class={"p-1 px-2 rounded-lg text-black #{if transaction.type == :income, do: "bg-green-300", else: "bg-red-300"}"}>
              {if transaction.type == :income, do: "Receita", else: "Despesa"}
            </span>
          </:col>
          <:col :let={{_id, transaction}} label="Data">
            <%= if transaction.inserted_at do %>
              {DateUtils.format_date(transaction.date)}
            <% else %>
              Data não disponível
            <% end %>
          </:col>
          <:col :let={{_id, transaction}} label="Descrição">{transaction.description}</:col>
          <:col :let={{_id, transaction}} label="Perfil">
            <span
              class="p-1 px-2 rounded-lg text-white"
              style={"background-color: #{transaction.profile && transaction.profile.color}99;"}
            >
              {transaction.profile && transaction.profile.name}
            </span>
          </:col>
          <:col :let={{_id, transaction}} label="Categoria">
            <span
              class="p-1 px-2 rounded-lg text-white"
              style={"background-color: #{transaction.category && transaction.category.color}99;"}
            >
              {transaction.category && transaction.category.name}
            </span>
          </:col>
          <:col :let={{_id, transaction}} label="Tipo de Investimento">
            {if(transaction.investment_type,
              do: transaction.investment_type.name,
              else: "-"
            )}
          </:col>
          <:col :let={{_id, transaction}} label="Quantidade">
            {if transaction.investment_type && transaction.investment_type.name == "Cripto",
              do: CurrencyUtils.format_amount(transaction.amount, true),
              else: CurrencyUtils.format_amount(transaction.amount, false)}
          </:col>
          <:col :let={{_id, transaction}} label="Valor Unitário">
            {CurrencyUtils.format_money(transaction.value)}
          </:col>
          <:col :let={{_id, transaction}} label="Valor Total">
            {CurrencyUtils.format_money(transaction.total_value)}
          </:col>
          <:action :let={{_id, transaction}}>
            <.link navigate={~p"/ledgers/#{@ledger.id}/transactions/#{transaction.id}/edit"}>
              <.icon name="hero-pencil" class="text-blue-500 hover:text-blue-800" />
            </.link>
          </:action>
          <:action :let={{_id, transaction}}>
            <.link phx-click="delete" phx-target={@myself} phx-value-id={transaction.id}>
              <.icon name="hero-trash" class="text-red-500 hover:text-red-800" />
            </.link>
          </:action>
        </.table>
        
        <div class="mt-4 flex justify-between items-center pt-4">
          <.button
            phx-click="previous_page"
            phx-target={@myself}
            variant="custom"
            class={"btn-primary btn-outline #{if @current_page <= 1, do: "btn-disabled", else: ""}"}
          >
            Anterior
          </.button>
          <span >
            Página {@current_page} de {@total_pages}
          </span>
          <.button
            phx-click="next_page"
            phx-target={@myself}
            variant="custom"
            class={"btn-primary btn-outline #{if @current_page >= @total_pages, do: "btn-disabled", else: ""}"}
          >
            Próximo
          </.button>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    transaction =
      Finance.get_transaction(current_scope, id, socket.assigns.ledger)

    case Finance.delete_transaction(current_scope, transaction) do
      {:ok, _deleted} ->
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao remover transação.")}
    end
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
      Finance.list_transactions(
        socket.assigns.current_scope,
        socket.assigns.ledger,
        socket.assigns.filter_params,
        new_page,
        socket.assigns.page_size
      )

    socket
    |> assign(:current_page, page_data.page_number)
    |> assign(:total_pages, page_data.total_pages)
    |> assign(:num_transactions, page_data.total_entries)
    |> stream(:transaction_collection, page_data.entries, reset: true)
  end
end
