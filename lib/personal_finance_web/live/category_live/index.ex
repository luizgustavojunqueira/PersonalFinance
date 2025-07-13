defmodule PersonalFinanceWeb.CategoryLive.Index do
  alias PersonalFinance.Finance.Ledger
  alias PersonalFinance.Finance.Category
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
        |> assign(ledger: ledger)
        |> stream(:category_collection, Finance.list_categories(current_scope, ledger))

      {:ok, socket |> apply_action(socket.assigns.live_action, params, ledger)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> apply_action(socket.assigns.live_action, params, socket.assigns.ledger)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params, ledger) do
    assign(socket,
      page_title: "Categorias - #{ledger.name}",
      ledger: ledger,
      show_form_modal: false,
      show_delete_modal: false,
      category: nil
    )
  end

  defp apply_action(socket, :new, _params, %Ledger{} = ledger) do
    category = %Category{ledger_id: ledger.id}

    assign(socket,
      page_title: "Categorias - #{ledger.name}",
      ledger: ledger,
      show_form_modal: true,
      show_delete_modal: false,
      category: category,
      form_action: :new,
      form:
        to_form(
          Finance.change_category(
            socket.assigns.current_scope,
            category,
            ledger
          )
        )
    )
  end

  defp apply_action(socket, :edit, %{"category_id" => category_id}, %Ledger{} = ledger) do
    category = Finance.get_category(socket.assigns.current_scope, category_id, ledger)

    if category == nil do
      socket
      |> put_flash(:error, "Categoria não encontrada.")
      |> push_navigate(to: ~p"/ledgers/#{ledger.id}/categories")
    else
      assign(socket,
        page_title: "Categorias - #{ledger.name}",
        show_form_modal: true,
        show_delete_modal: false,
        ledger: ledger,
        category: category,
        form_action: :edit,
        form:
          to_form(
            Finance.change_category(
              socket.assigns.current_scope,
              category,
              ledger
            )
          )
      )
    end
  end

  defp apply_action(socket, :delete, %{"category_id" => category_id}, %Ledger{} = ledger) do
    category = Finance.get_category(socket.assigns.current_scope, category_id, ledger)

    assign(socket,
      page_title: "Categorias - #{ledger.name}",
      ledger: ledger,
      show_form_modal: false,
      show_delete_modal: true,
      category: category,
      form_action: nil
    )
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    category = Finance.get_category(current_scope, id, socket.assigns.ledger)

    case Finance.delete_category(current_scope, category) do
      {:ok, _deleted} ->
        {:noreply,
         Phoenix.LiveView.push_patch(socket,
           to: ~p"/ledgers/#{socket.assigns.ledger.id}/categories"
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao remover categoria.")}
    end
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply,
     socket
     |> assign(show_form_modal: false, category: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers/#{socket.assigns.ledger.id}/categories")}
  end

  @impl true
  def handle_event("close_confirmation", _params, socket) do
    {:noreply,
     socket
     |> assign(show_delete_modal: false, category: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers/#{socket.assigns.ledger.id}/categories")}
  end

  @impl true
  def handle_event("save", %{"category" => category_params}, socket) do
    save_category(socket, socket.assigns.form_action, category_params)
  end

  @impl true
  def handle_event("validate", %{"category" => category_params}, socket) do
    changeset =
      Finance.change_category(
        socket.assigns.current_scope,
        socket.assigns.category,
        socket.assigns.ledger,
        category_params
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate)
     )}
  end

  defp save_category(socket, :edit, category_params) do
    case Finance.update_category(
           socket.assigns.current_scope,
           socket.assigns.category,
           category_params
         ) do
      {:ok, _category} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_category(socket, :new, category_params) do
    case Finance.create_category(
           socket.assigns.current_scope,
           category_params,
           socket.assigns.ledger
         ) do
      {:ok, _category} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Category Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_info({:saved, category}, socket) do
    {:noreply,
     socket
     |> stream_insert(:category_collection, category)
     |> assign(show_form_modal: false, category: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers/#{socket.assigns.ledger.id}/categories")}
  end

  @impl true
  def handle_info({:deleted, category}, socket) do
    {:noreply,
     socket
     |> stream_delete(:category_collection, category)}
  end
end
