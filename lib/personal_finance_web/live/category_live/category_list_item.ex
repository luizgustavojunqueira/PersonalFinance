defmodule PersonalFinanceWeb.CategoryLive.CategoryListItem do
  use PersonalFinanceWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <li class="grid grid-cols-4 gap-4 mb-4 p-3 rounded-md shadow-sm light" id={@id}>
      <span class="font-medium ">{@category.name}</span>
      <span class="font-medium ">{@category.description}</span>
      <span class="font-medium ">{@category.percentage}</span>

      <span class="flex space-x-2">
        <.link
          class="text-blue-600 hover:text-blue-800 hero-pencil"
          phx-click="edit_category"
          phx-value-id={@category.id}
          phx-target={@myself}
        >
        </.link>
        <.link
          class="text-red-600 hover:text-red-800 hero-trash"
          phx-click="delete_category"
          phx-value-id={@category.id}
          phx-target={@myself}
          data-confirm="Você tem certeza que deseja excluir esta transação?"
        >
        </.link>
      </span>
    </li>
    """
  end

  @impl true
  def handle_event("edit_category", %{"id" => id}, socket) do
    send(socket.assigns.parent_pid, {:edit_category, id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    send(socket.assigns.parent_pid, {:delete_category, id})
    {:noreply, socket}
  end
end
