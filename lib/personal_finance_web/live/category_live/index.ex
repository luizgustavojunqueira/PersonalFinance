defmodule PersonalFinanceWeb.CategoryLive.Index do
  alias PersonalFinance.Finance.Category
  alias PersonalFinance.Finance
  alias PersonalFinance.PubSub
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    if current_user do
      Phoenix.PubSub.subscribe(
        PubSub,
        "categories_updates:#{current_user.id}"
      )
    end

    categories = Finance.list_categories_for_user(current_user)

    changeset = Category.changeset(%Category{}, %{})

    socket =
      socket
      |> assign(
        changeset: changeset,
        selected_category: nil,
        show_form: false
      )
      |> stream(:categories, categories, id: & &1.id)

    {:ok, socket}
  end

  @impl true
  def handle_event("create_category", %{"category" => category_params}, socket) do
    current_user = socket.assigns.current_scope.user

    params_with_user = Map.put(category_params, "user_id", current_user.id)

    case Finance.create_category(params_with_user) do
      {:ok, added} ->
        new_changeset = Category.changeset(%Category{}, %{})

        {:noreply,
         socket
         |> stream_insert(:categories, added)
         |> assign(
           changeset: new_changeset,
           selected_category: nil,
           show_form: false
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("validate_category", %{"category" => category_params}, socket) do
    changeset =
      Category.changeset(
        socket.assigns.selected_category || %Category{},
        category_params
      )

    {:noreply,
     assign(socket,
       action: :validate,
       changeset: changeset
     )}
  end

  def handle_event("open_form", _params, socket) do
    {:noreply, assign(socket, show_form: true, selected_category: nil)}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, selected_category: nil)}
  end

  def handle_event("update_category", %{"category" => category_params}, socket) do
    c = socket.assigns.selected_category

    case Finance.update_category(c, category_params) do
      {:ok, updated} ->
        new_changeset = Category.changeset(%Category{}, %{})

        {:noreply,
         socket
         |> stream_insert(:categorys, updated)
         |> assign(
           changeset: new_changeset,
           selected_category: nil,
           show_form: false
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_info({:edit_category, id}, socket) do
    category = Finance.get_category!(String.to_integer(id))
    changeset = Category.changeset(category, %{})

    {:noreply,
     assign(socket,
       selected_category: category,
       show_form: true,
       changeset: changeset
     )}
  end

  @impl true
  def handle_info({:delete_category, id}, socket) do
    category = Finance.get_category!(String.to_integer(id))

    case Finance.delete_category(category) do
      {:ok, deleted} ->
        {:noreply, stream_delete(socket, :categories, deleted)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:category_changed, user_id}, socket)
      when socket.assigns.current_scope.user.id == user_id do
    categories = Finance.list_categories_for_user(socket.assigns.current_scope.user)

    socket =
      socket
      |> stream(:categories, categories)

    {:noreply, socket}
  end
end
