defmodule PersonalFinanceWeb.HomeLive.Index do
  alias PersonalFinance.PubSub
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    if current_user do
      Phoenix.PubSub.subscribe(
        PubSub,
        "transactions_updates:#{current_user.id}"
      )
    end

    transactions = PersonalFinance.Finance.list_transactions_for_user(current_user)
    categories = PersonalFinance.Finance.list_categories_for_user(current_user)

    labels =
      Enum.map(categories, fn category ->
        category.name
      end)

    values =
      Enum.map(categories, fn category ->
        PersonalFinance.Finance.get_total_value_by_category(category.id, transactions)
      end)

    socket =
      socket
      |> assign(
        current_user: current_user,
        page_title: "Home",
        show_welcome_message: true,
        labels: labels,
        values: values
      )

    {:ok, socket}
  end

  @impl true
  def handle_info({:transaction_changed, user_id}, socket)
      when socket.assigns.current_scope.user.id == user_id do
    transactions =
      PersonalFinance.Finance.list_transactions_for_user(socket.assigns.current_scope.user)

    categories =
      PersonalFinance.Finance.list_categories_for_user(socket.assigns.current_scope.user)

    labels =
      Enum.map(categories, fn category ->
        category.name
      end)

    values =
      Enum.map(categories, fn category ->
        PersonalFinance.Finance.get_total_value_by_category(category.id, transactions)
      end)

    IO.inspect(labels)
    IO.inspect(values)

    socket =
      socket
      |> assign(
        labels: labels,
        values: values
      )

    {:noreply, socket}
  end
end
