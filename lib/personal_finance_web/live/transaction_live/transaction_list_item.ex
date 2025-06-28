defmodule PersonalFinanceWeb.TransactionLive.TransactionListItem do
  use PersonalFinanceWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <li class="grid grid-cols-9 gap-4 mb-4 p-3 rounded-md shadow-sm light" id={@id}>
      <span class="text-sm ">
        <%= if @transaction.inserted_at do %>
          {format_date(@transaction.date)}
        <% else %>
          Data não disponível
        <% end %>
      </span>
      <span class="font-medium ">{@transaction.description}</span>
      <span class="font-medium ">{@transaction.profile && @transaction.profile.name}</span>
      <span class="font-medium ">{@transaction.category.name}</span>
      <span class="font-medium ">
        {@transaction.investment_type && @transaction.investment_type.name}
      </span>
      <span class="font-medium ">
        {if @transaction.investment_type && @transaction.investment_type.name == "Cripto",
          do: format_amount(@transaction.amount, true),
          else: format_amount(@transaction.amount, false)}
      </span>

      <span class="font-medium ">
        {format_money(@transaction.value)}
      </span>

      <span class="font-medium ">
        {format_money(@transaction.total_value)}
      </span>
      <span class="flex space-x-2">
        <.link
          class="text-blue-600 hover:text-blue-800 hero-pencil"
          phx-click="edit_transaction"
          phx-value-id={@transaction.id}
          phx-target={@myself}
        >
        </.link>
        <.link
          class="text-red-600 hover:text-red-800 hero-trash"
          phx-click="delete_transaction"
          phx-value-id={@transaction.id}
          phx-target={@myself}
          data-confirm="Você tem certeza que deseja excluir esta transação?"
        >
        </.link>
      </span>
    </li>
    """
  end

  @impl true
  def handle_event("edit_transaction", %{"id" => id}, socket) do
    send(socket.assigns.parent_pid, {:edit_transaction, id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_transaction", %{"id" => id}, socket) do
    send(socket.assigns.parent_pid, {:delete_transaction, id})
    {:noreply, socket}
  end

  def format_date(nil), do: "Data não disponível"
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")
  def format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  def format_date(_), do: "Data inválida"

  def format_money(nil), do: "R$ 0,00"

  def format_money(value) when is_float(value) or is_integer(value) do
    formatted_value = :erlang.float_to_binary(value, [:compact, decimals: 2])
    "R$ #{formatted_value}"
  end

  def format_amount(nil), do: "0,00"

  def format_amount(value, cripto \\ false) when is_float(value) or is_integer(value) do
    if cripto do
      :erlang.float_to_binary(value, [:compact, decimals: 8])
    else
      :erlang.float_to_binary(value, [:compact, decimals: 2])
    end
  end
end
