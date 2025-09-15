defmodule PersonalFinanceWeb.LedgersLive.Index do
  alias PersonalFinance.Finance
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
  def handle_event("open_modal", %{"modal" => modal}, socket) do
    modal_atom = String.to_existing_atom(modal)
    {:noreply, assign(socket, open_modal: modal_atom, transaction: nil)}
  end

  @impl true
  def handle_event("open_edit_modal", %{"id" => ledger_id}, socket) do
    current_scope = socket.assigns.current_scope

    ledger = PersonalFinance.Finance.get_ledger(current_scope, ledger_id)

    if ledger do
      {:noreply,
       assign(socket,
         open_modal: :edit_ledger,
         ledger: ledger
       )}
    else
      {:noreply, put_flash(socket, :error, "Ledger not found.")}
    end
  end

  @impl true
  def handle_event("open_delete_modal", %{"id" => ledger_id}, socket) do
    current_scope = socket.assigns.current_scope
    ledger = PersonalFinance.Finance.get_ledger(current_scope, ledger_id)

    if ledger do
      {:noreply,
       assign(socket,
         open_modal: :delete_ledger,
         ledger: ledger
       )}
    else
      {:noreply, put_flash(socket, :error, "Ledger not found.")}
    end
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, open_modal: nil, transaction: nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    ledger = PersonalFinance.Finance.get_ledger(current_scope, id)

    case PersonalFinance.Finance.delete_ledger(current_scope, ledger) do
      {:ok, _deleted} ->
        {:noreply,
         socket
         |> assign(ledger: nil, open_modal: nil)
         |> put_flash(:info, "Ledger excluído com sucesso.")
         |> stream_delete(:ledger_collection, ledger)}

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
     |> stream_insert(:ledger_collection, ledger)
     |> assign(open_modal: nil)}
  end
end
