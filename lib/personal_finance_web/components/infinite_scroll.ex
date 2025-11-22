defmodule PersonalFinanceWeb.Components.InfiniteScroll do
  use PersonalFinanceWeb, :live_component

  @default_per_page 20

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       page: 0,
       per_page: @default_per_page,
       has_more: true,
       loading: false,
       initialized: false,
       total_items: 0,
       total_pages: 0,
       current_items_count: 0,
       item_ids: []
     )}
  end

  @impl true
  def update(%{action: :insert_new_item, item: item}, socket) do
    stream_name = String.to_existing_atom(socket.assigns.stream_name)
    item_ids = socket.assigns.item_ids
    new_item_ids = [item.id | item_ids]

    socket =
      socket
      |> stream_insert(stream_name, item, at: 0)
      |> assign(
        item_ids: new_item_ids,
        current_items_count: length(new_item_ids),
        total_items: socket.assigns.total_items + 1,
        total_pages: ceil((socket.assigns.total_items + 1) / socket.assigns.per_page)
      )

    {:ok, socket}
  end

  def update(%{trigger_load: true}, socket) do
    {:ok, load_next_page(socket)}
  end

  def update(%{action: :reset}, socket) do
    stream_name = String.to_existing_atom(socket.assigns.stream_name)

    {:ok,
     socket
     |> assign(
       page: 0,
       has_more: true,
       loading: false,
       initialized: false,
       current_items_count: 0,
       item_ids: []
     )
     |> stream(stream_name, [], reset: true)
     |> load_next_page()}
  end

  def update(assigns, socket) do
    per_page = Map.get(assigns, :per_page, @default_per_page)

    socket =
      socket
      |> assign(assigns)
      |> assign(per_page: per_page)
      |> maybe_init_stream()

    socket =
      if not socket.assigns.initialized do
        socket
        |> assign(initialized: true)
        |> load_next_page()
      else
        socket
      end

    {:ok, socket}
  end

  defp maybe_init_stream(socket) do
    stream_name = String.to_existing_atom(socket.assigns.stream_name)
    stream(socket, stream_name, [])
  end

  @impl true
  def handle_event("load-more", _params, socket) do
    if socket.assigns.has_more and not socket.assigns.loading do
      send_update_after(self(), __MODULE__, [id: socket.assigns.id, trigger_load: true], 1)
      {:noreply, assign(socket, loading: true)}
    else
      {:noreply, socket}
    end
  end

  defp load_next_page(socket) do
    %{
      loader_mfa: {module, function, base_args},
      per_page: per_page,
      page: current_page
    } = socket.assigns

    next_page = current_page + 1

    args = base_args ++ [[page: next_page, per_page: per_page]]

    case apply(module, function, args) do
      %{
        items: items,
        total_items: total_items,
        items_in_page: items_in_page,
        total_pages: total_pages
      }
      when is_list(items) ->
        handle_load_result(socket, items, %{
          total_items: total_items,
          items_in_page: items_in_page,
          total_pages: total_pages,
          page: next_page
        })

      {items, has_more} when is_list(items) and is_boolean(has_more) ->
        handle_load_result(socket, items, %{
          has_more: has_more,
          page: next_page
        })

      _ ->
        socket
        |> assign(loading: false, has_more: false)
    end
  rescue
    e ->
      IO.inspect(e, label: "Error loading data")
      IO.inspect(__STACKTRACE__, label: "Stacktrace")
      assign(socket, loading: false, has_more: false)
  end

  defp handle_load_result(socket, items, metadata) do
    stream_name = String.to_existing_atom(socket.assigns.stream_name)
    item_ids = socket.assigns.item_ids

    new_item_ids = item_ids ++ Enum.map(items, & &1.id)

    socket = stream_batch_insert(socket, stream_name, items)

    has_more =
      cond do
        Map.has_key?(metadata, :has_more) ->
          metadata.has_more

        Map.has_key?(metadata, :total_pages) ->
          metadata.page < metadata.total_pages

        true ->
          length(items) == socket.assigns.per_page
      end

    assign(socket,
      page: metadata.page,
      has_more: has_more,
      loading: false,
      item_ids: new_item_ids,
      current_items_count: length(new_item_ids),
      total_items: Map.get(metadata, :total_items, socket.assigns.total_items + length(items)),
      total_pages: Map.get(metadata, :total_pages, socket.assigns.total_pages)
    )
  end

  defp stream_batch_insert(socket, stream_name, items) do
    Enum.reduce(items, socket, fn item, acc_socket ->
      stream_insert(acc_socket, stream_name, item, at: -1)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={@wrapper_class || ""}>
      <%= if @total_items > 0 do %>
        <div class="flex justify-between items-center text-sm text-base-content/70 mb-2 px-1">
          <span>
            Loaded {@current_items_count} of {@total_items}
          </span>
          <span>
            Page {@page}/{@total_pages}
          </span>
        </div>
      <% end %>
      {render_slot(@content, @streams[String.to_existing_atom(@stream_name)])}

      <div
        id={"#{@id}-infinite-scroll-marker"}
        phx-hook="InfiniteScroll"
        phx-target={@myself}
        data-page={@page}
        class="h-px"
      >
      </div>

      <%= if @loading do %>
        <div class="flex justify-center py-6">
          <span class="loading loading-dots text-primary"></span>
        </div>
      <% end %>

      <%= if not @has_more and @page > 0 do %>
        <%= if assigns[:empty_slot] && @empty_slot != [] do %>
          {render_slot(@empty_slot)}
        <% else %>
          <div class="text-center py-4 text-base-content/60 text-sm">
            <%= if @current_items_count == 0 do %>
              No items found
            <% else %>
              All items loaded
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
