defmodule PersonalFinanceWeb.LedgersLive.Index do
  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Ledger
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> stream(:ledger_collection, Finance.list_ledgers(current_scope))
      |> assign(
        page_title: "Ledgers",
        ledger: nil,
        open_modal: nil
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
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    with %Ledger{} = ledger <- Finance.get_ledger(current_scope, id),
         {:ok, _deleted} <- Finance.delete_ledger(current_scope, ledger) do
      {:noreply,
       socket
       |> assign(ledger: nil, open_modal: nil)
       |> put_flash(:info, "Ledger excluído com sucesso.")
       |> stream_delete(:ledger_collection, ledger)
       |> push_patch(to: ~p"/ledgers")}
    else
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Ledger não encontrado.")
         |> push_patch(to: ~p"/ledgers")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Erro ao excluir o ledger"
         )}
    end
  end

  @impl true
  def handle_info({:saved, ledger}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Ledger salvo com sucesso.")
      |> stream_insert(:ledger_collection, ledger, at: 0, replace: true)
      |> assign(open_modal: nil, ledger: nil)
     |> push_patch(to: ~p"/ledgers")}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, open_modal: nil, ledger: nil, page_title: "Ledgers")
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, open_modal: :new_ledger, ledger: nil, page_title: "Novo Ledger")
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
        |> put_flash(:error, "Ledger não encontrado.")
        |> push_patch(to: ~p"/ledgers")
    end
  end

  defp modal_name(:edit), do: :edit_ledger
  defp modal_name(:delete), do: :delete_ledger

  defp page_title(:edit, ledger), do: "Editar Ledger - #{ledger.name}"
  defp page_title(:delete, ledger), do: "Excluir Ledger - #{ledger.name}"
end
