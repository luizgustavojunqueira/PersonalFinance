defmodule PersonalFinanceWeb.TransactionLive.Transactions do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Utils.{CurrencyUtils, DateUtils, ParseUtils}
  alias PersonalFinance.Finance
  alias PersonalFinanceWeb.Components.InfiniteScroll

  @default_page_size 25

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:page_size, @default_page_size)
     |> assign(:filter, %{})
     |> assign(:profiles, [])
     |> assign(:categories, [])
     |> assign(:investment_types, [])}
  end

  @impl true
  def update(assigns, socket) do
    page_size = Map.get(assigns, :page_size, socket.assigns[:page_size] || @default_page_size)

    socket =
      socket
      |> assign(:page_size, page_size)
      |> assign_new(:filter, fn -> %{} end)
      |> assign_new(:profiles, fn -> [] end)
      |> assign_new(:categories, fn -> [] end)
      |> assign_new(:investment_types, fn -> [] end)
      |> assign(assigns)
      |> assign(:scroll_id, build_scroll_id(assigns, socket))

    socket = handle_action(assigns, socket)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.live_component
        module={InfiniteScroll}
        id={@scroll_id}
        stream_name="transaction_collection"
        loader_mfa={{__MODULE__, :fetch_transactions, [@current_scope, @ledger]}}
        per_page={@page_size}
        wrapper_class="flex flex-col gap-4"
        filter_config={filter_config(assigns)}
        initial_filters={@filter}
        filter_change_target={@parent_pid || self()}
        filter_change_message={:transactions_filter_changed}
      >
        <:content :let={transactions_stream}>
          <.table
            id="transactions_table"
            rows={transactions_stream}
            col_widths={["7%", "7%", "10%", "12%", "12%", "15%", "10%", "10%", "10%"]}
            row_item={
              fn
                {_, struct} -> struct
                struct -> struct
              end
            }
          >
            <:col :let={transaction} label="Tipo">
              <span class={[
                "p-1 px-2 rounded-lg text-black",
                if(transaction.type == :income, do: "bg-green-300", else: "bg-red-300")
              ]}>
                {if transaction.type == :income, do: "Receita", else: "Despesa"}
              </span>
            </:col>
            <:col :let={transaction} label="Data">
              <%= if transaction.date do %>
                {DateUtils.to_local_time_with_date(transaction.date) |> DateUtils.format_date()}
              <% else %>
                Data não disponível
              <% end %>
            </:col>
            <:col :let={transaction} label="Descrição">
              <.text_ellipsis text={transaction.description} max_width="max-w-[10rem]" />
            </:col>
            <:col :let={transaction} label="Perfil">
              <div
                class="rounded-lg text-white text-center w-fit"
                style={"background-color: #{transaction.profile && transaction.profile.color}99;"}
              >
                <.text_ellipsis
                  class="p-1 px-2"
                  text={transaction.profile && transaction.profile.name}
                  max_width="max-w-[10rem]"
                />
              </div>
            </:col>
            <:col :let={transaction} label="Categoria">
              <div
                class="rounded-lg text-white text-center w-fit"
                style={"background-color: #{transaction.category && transaction.category.color}99;"}
              >
                <.text_ellipsis
                  class="p-1 px-2"
                  text={transaction.category && transaction.category.name}
                  max_width="max-w-[10rem]"
                />
              </div>
            </:col>
            <:col :let={transaction} label="Tipo de Investimento">
              <.text_ellipsis
                text={if transaction.investment_type, do: transaction.investment_type.name, else: "-"}
                max_width="max-w-[10rem]"
              />
            </:col>
            <:col :let={transaction} label="Quantidade">
              {if transaction.investment_type && transaction.investment_type.name == "Cripto",
                do: CurrencyUtils.format_amount(transaction.amount, true),
                else: CurrencyUtils.format_amount(transaction.amount, false)}
            </:col>
            <:col :let={transaction} label="Valor Unitário">
              {CurrencyUtils.format_money(transaction.value)}
            </:col>
            <:col :let={transaction} label="Valor Total">
              {CurrencyUtils.format_money(transaction.total_value)}
            </:col>
            <:action :let={transaction}>
              <.link phx-click="open_edit_transaction" phx-value-transaction_id={transaction.id}>
                <.icon name="hero-pencil" class="text-blue-500 hover:text-blue-800" />
              </.link>
            </:action>
            <:action :let={transaction}>
              <.link phx-click="delete" phx-target={@myself} phx-value-id={transaction.id}>
                <.icon name="hero-trash" class="text-red-500 hover:text-red-800" />
              </.link>
            </:action>
          </.table>
        </:content>
        <:empty_slot>
          <div class="text-center py-4 text-gray-500">Nenhuma transação encontrada.</div>
        </:empty_slot>
      </.live_component>
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

  defp handle_action(%{action: :saved, transaction: transaction}, socket) do
    send_update(InfiniteScroll,
      id: socket.assigns.scroll_id,
      action: :insert_new_item,
      item: transaction
    )

    socket
  end

  defp handle_action(%{action: :deleted, transaction: transaction}, socket) do
    send_update(InfiniteScroll,
      id: socket.assigns.scroll_id,
      action: :delete_item,
      item: transaction
    )

    socket
  end

  defp handle_action(%{action: :update}, socket) do
    send_update(InfiniteScroll, id: socket.assigns.scroll_id, action: :reset)
    socket
  end

  defp handle_action(_, socket), do: socket

  def fetch_transactions(scope, ledger, opts) do
    filters = Map.get(opts, :filters, %{})
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, @default_page_size)

    data = Finance.list_transactions(scope, ledger, filters || %{}, page, per_page)

    %{
      items: data.entries,
      total_items: data.total_entries,
      items_in_page: length(data.entries),
      total_pages: data.total_pages
    }
  end

  defp filter_config(assigns) do
    [
      %{
        name: :profile_id,
        type: "select",
        label: "Perfil",
        options: assigns.profiles,
        prompt: "Selecione um perfil",
        parser: &ParseUtils.parse_id/1,
        to_form_value: &to_select_value/1,
        match: fn transaction, value -> transaction.profile_id == value end
      },
      %{
        name: :type,
        type: "select",
        label: "Tipo",
        options: [{"Receita", :income}, {"Despesa", :expense}],
        prompt: "Selecione um tipo",
        parser: &parse_type/1,
        to_form_value: &to_type_value/1,
        match: fn transaction, value -> transaction.type == value end
      },
      %{
        name: :category_id,
        type: "select",
        label: "Categoria",
        options: assigns.categories,
        prompt: "Selecione uma categoria",
        parser: &ParseUtils.parse_id/1,
        to_form_value: &to_select_value/1,
        match: fn transaction, value -> transaction.category_id == value end
      },
      %{
        name: :investment_type_id,
        type: "select",
        label: "Tipo de Investimento",
        options: assigns.investment_types,
        prompt: "Selecione um tipo de investimento",
        parser: &ParseUtils.parse_id/1,
        to_form_value: &to_select_value/1,
        match: fn transaction, value -> transaction.investment_type_id == value end
      },
      %{
        name: :start_date,
        type: "date",
        label: "Data Inicial",
        parser: &parse_start_date/1,
        to_form_value: &to_date_value/1,
        match: fn transaction, value -> match_start_date(transaction.date, value) end
      },
      %{
        name: :end_date,
        type: "date",
        label: "Data Final",
        parser: &parse_end_date/1,
        to_form_value: &to_date_value/1,
        match: fn transaction, value -> match_end_date(transaction.date, value) end
      }
    ]
  end

  defp to_select_value(nil), do: nil
  defp to_select_value(value) when is_binary(value), do: value
  defp to_select_value(value), do: to_string(value)

  defp parse_type(nil), do: nil
  defp parse_type(""), do: nil
  defp parse_type(value) when is_atom(value), do: value

  defp parse_type(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> String.to_existing_atom(trimmed)
    end
  rescue
    _ -> nil
  end

  defp parse_type(_), do: nil

  defp to_type_value(nil), do: nil
  defp to_type_value(value) when is_binary(value), do: value
  defp to_type_value(value) when is_atom(value), do: Atom.to_string(value)
  defp to_type_value(value), do: to_string(value)

  defp parse_start_date(nil), do: nil
  defp parse_start_date(""), do: nil
  defp parse_start_date(%DateTime{} = datetime), do: datetime

  defp parse_start_date(%Date{} = date) do
    DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  end

  defp parse_start_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _ -> nil
    end
  end

  defp parse_start_date(_), do: nil

  defp parse_end_date(nil), do: nil
  defp parse_end_date(""), do: nil
  defp parse_end_date(%DateTime{} = datetime), do: datetime

  defp parse_end_date(%Date{} = date) do
    DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
  end

  defp parse_end_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
      _ -> nil
    end
  end

  defp parse_end_date(_), do: nil

  defp to_date_value(nil), do: nil

  defp to_date_value(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_date()
    |> Date.to_iso8601()
  end

  defp to_date_value(%Date{} = date), do: Date.to_iso8601(date)
  defp to_date_value(value) when is_binary(value), do: value
  defp to_date_value(_), do: nil

  defp match_start_date(nil, _value), do: false

  defp match_start_date(date, value) do
    DateTime.compare(date, value) != :lt
  end

  defp match_end_date(nil, _value), do: false

  defp match_end_date(date, value) do
    DateTime.compare(date, value) != :gt
  end

  defp build_scroll_id(assigns, socket) do
    base_id =
      case {Map.get(assigns, :id), Map.get(socket.assigns, :id)} do
        {id, _} when is_binary(id) and id != "" -> id
        {_, id} when is_binary(id) and id != "" -> id
        _ -> "transactions-list"
      end

    base_id
    |> to_string()
    |> Kernel.<>("-scroll")
  end
end
