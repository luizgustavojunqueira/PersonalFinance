defmodule PersonalFinanceWeb.CategoryLive.Index do
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope

    ledger = Finance.get_ledger(current_scope, params["id"])

    if ledger == nil do
      {:ok,
       socket
       |> put_flash(:error, "Orçamento não encontrado.")
       |> push_navigate(to: ~p"/ledgers")}
    else
      Finance.subscribe_finance(:category, ledger.id)

      socket =
        socket
        |> assign(ledger: ledger, open_modal: nil, category: nil)
        |> stream(:category_collection, Finance.list_categories(current_scope, ledger))

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("open_edit_category", %{"category_id" => category_id}, socket) do
    category =
      Finance.get_category(socket.assigns.current_scope, category_id, socket.assigns.ledger)

    if category == nil do
      socket
      |> put_flash(:error, "Categoria não encontrada.")
    else
      {:noreply,
       assign(socket,
         open_modal: :edit_category,
         category: category
       )}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    category = Finance.get_category(current_scope, id, socket.assigns.ledger)

    case Finance.delete_category(current_scope, category) do
      {:ok, _deleted} ->
        {:noreply,
         socket
         |> assign(open_modal: nil, category: nil)
         |> put_flash(:info, "Categoria removida com sucesso.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao remover categoria.")}
    end
  end

  @impl true
  def handle_event("open_modal", %{"modal" => modal}, socket) do
    modal_atom = String.to_existing_atom(modal)
    {:noreply, assign(socket, open_modal: modal_atom, transaction: nil)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, open_modal: nil, transaction: nil)}
  end

  @impl true
  def handle_event("open_delete_modal", %{"category_id" => category_id}, socket) do
    current_scope = socket.assigns.current_scope

    category =
      Finance.get_category(current_scope, category_id, socket.assigns.ledger)

    if category do
      {:noreply,
       assign(socket,
         open_modal: :delete_category,
         category: category
       )}
    else
      {:noreply, put_flash(socket, :error, "Category not found.")}
    end
  end

  @impl true
  def handle_info({:saved, category}, socket) do
    {:noreply,
     socket
     |> stream_insert(:category_collection, category)
     |> assign(open_modal: false, category: nil)}
  end

  @impl true
  def handle_info({:deleted, category}, socket) do
    {:noreply,
     socket
     |> stream_delete(:category_collection, category)}
  end
end
