defmodule PersonalFinanceWeb.LedgersLive.Index do
  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Ledger
  alias PersonalFinance.Balance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope
    ledgers = Finance.list_ledgers(current_scope)
    ledgers_with_stats = Enum.map(ledgers, &enrich_ledger_with_stats(&1, current_scope))

    socket =
      socket
      |> stream(:ledger_collection, ledgers_with_stats)
      |> assign(
        page_title: gettext("Ledgers"),
        ledger: nil,
        open_modal: nil,
        has_own_ledgers: Enum.any?(ledgers, fn l -> l.owner.id == current_scope.user.id end),
        has_shared_ledgers: Enum.any?(ledgers, fn l -> l.owner.id != current_scope.user.id end),
        has_any_ledgers: not Enum.empty?(ledgers)
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(open_modal: nil, ledger: nil)
     |> push_patch(to: ~p"/ledgers")}
  end

  @impl true
  def handle_event("change_locale", %{"locale" => locale}, socket) do
    Gettext.put_locale(PersonalFinanceWeb.Gettext, locale)
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    with %Ledger{} = ledger <- Finance.get_ledger(current_scope, id),
         {:ok, _deleted} <- Finance.delete_ledger(current_scope, ledger) do
      ledgers = Finance.list_ledgers(current_scope)

      {:noreply,
       socket
       |> assign(ledger: nil, open_modal: nil)
       |> put_flash(:info, gettext("Ledger deleted successfully."))
       |> stream_delete(:ledger_collection, ledger)
       |> assign(
         has_own_ledgers: Enum.any?(ledgers, fn l -> l.owner.id == current_scope.user.id end),
         has_shared_ledgers: Enum.any?(ledgers, fn l -> l.owner.id != current_scope.user.id end),
         has_any_ledgers: not Enum.empty?(ledgers)
       )
       |> push_patch(to: ~p"/ledgers")}
    else
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Ledger not found."))
         |> push_patch(to: ~p"/ledgers")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error deleting ledger")
         )}
    end
  end

  @impl true
  def handle_info({:saved, ledger}, socket) do
    current_scope = socket.assigns.current_scope
    ledgers = Finance.list_ledgers(current_scope)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Ledger saved successfully."))
     |> stream_insert(:ledger_collection, ledger, at: 0, replace: true)
     |> assign(
       open_modal: nil,
       ledger: nil,
       has_own_ledgers: Enum.any?(ledgers, fn l -> l.owner.id == current_scope.user.id end),
       has_shared_ledgers: Enum.any?(ledgers, fn l -> l.owner.id != current_scope.user.id end),
       has_any_ledgers: not Enum.empty?(ledgers)
     )
     |> push_patch(to: ~p"/ledgers")}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, open_modal: nil, ledger: nil, page_title: gettext("Ledgers"))
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, open_modal: :new_ledger, ledger: nil, page_title: gettext("New Ledger"))
  end

  defp apply_action(socket, action, %{"id" => id}) when action in [:edit, :delete] do
    current_scope = socket.assigns.current_scope

    case Finance.get_ledger(current_scope, id) do
      %Ledger{} = ledger ->
        assign(socket,
          open_modal: modal_name(action),
          ledger: ledger,
          page_title: page_title(action, ledger)
        )

      nil ->
        socket
        |> put_flash(:error, gettext("Ledger not found."))
        |> push_patch(to: ~p"/ledgers")
    end
  end

  defp modal_name(:edit), do: :edit_ledger
  defp modal_name(:delete), do: :delete_ledger

  defp page_title(:edit, ledger), do: gettext("Edit Ledger - %{name}", name: ledger.name)
  defp page_title(:delete, ledger), do: gettext("Delete Ledger - %{name}", name: ledger.name)

  defp enrich_ledger_with_stats(ledger, current_scope) do
    balance = Balance.get_balance(current_scope, ledger.id, :all, nil)
    month_balance = Balance.get_balance(current_scope, ledger.id, :monthly, nil)

    transaction_count = Finance.count_transactions(current_scope, ledger.id)

    Map.merge(ledger, %{
      stats: %{
        balance: balance.balance,
        month_balance: month_balance.balance,
        transaction_count: transaction_count
      }
    })
  end
end
