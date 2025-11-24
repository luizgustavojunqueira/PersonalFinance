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
       item_ids: [],
       item_id_set: MapSet.new(),
       filter_config: [],
       filters_initialized?: false,
       filters: %{},
       default_filters: %{},
       filter_form_data: %{},
       default_form_data: %{},
       filter_form: to_filter_form(%{}),
       filter_change_target: nil,
       filter_change_message: nil
     )}
  end

  @impl true
  def update(%{action: :insert_new_item, item: item}, socket) do
    {:ok, handle_insert(socket, item)}
  end

  def update(%{action: :delete_item, item: item}, socket) do
    {:ok, handle_delete(socket, item)}
  end

  def update(%{action: :reset}, socket) do
    stream_atom = ensure_stream_atom(socket).assigns.stream_atom

    socket =
      socket
      |> assign(
        page: 0,
        has_more: true,
        loading: true,
        initialized: true,
        current_items_count: 0,
        total_items: 0,
        total_pages: 0,
        item_ids: [],
        item_id_set: MapSet.new()
      )
      |> stream(stream_atom, [], reset: true)

    {:ok, load_next_page(socket)}
  end

  def update(%{trigger_load: true}, socket) do
    {:ok, load_next_page(socket)}
  end

  def update(assigns, socket) do
    per_page = Map.get(assigns, :per_page, socket.assigns.per_page || @default_per_page)
    filter_config = Map.get(assigns, :filter_config, socket.assigns.filter_config)

    socket =
      socket
      |> assign(assigns)
      |> assign(per_page: per_page)
      |> assign(filter_config: filter_config)
      |> ensure_stream_atom()
      |> maybe_init_filters(assigns)
      |> maybe_init_stream()

    socket =
      if socket.assigns.initialized do
        socket
      else
        socket
        |> assign(initialized: true, loading: true)
        |> load_next_page()
      end

    {:ok, socket}
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

  def handle_event("apply_filters", %{"filter" => params}, socket) do
    {parsed_filters, form_data} = parse_filters_from_params(socket.assigns.filter_config, params)

    filters =
      Map.merge(socket.assigns.default_filters, parsed_filters, fn _k, _default, value ->
        value
      end)

    form_data =
      Map.merge(socket.assigns.default_form_data, form_data, fn _k, default, value ->
        if value in [nil, ""], do: default, else: value
      end)

    stream_atom = socket.assigns.stream_atom

    socket =
      socket
      |> assign(
        filters: filters,
        filter_form_data: form_data,
        filter_form: to_filter_form(form_data),
        page: 0,
        has_more: true,
        loading: true,
        current_items_count: 0,
        total_items: 0,
        total_pages: 0,
        item_ids: [],
        item_id_set: MapSet.new()
      )
      |> stream(stream_atom, [], reset: true)
      |> notify_filters_change()

    {:noreply, load_next_page(socket)}
  end

  def handle_event("reset_filters", _params, socket) do
    stream_atom = socket.assigns.stream_atom

    socket =
      socket
      |> assign(
        filters: socket.assigns.default_filters,
        filter_form_data: socket.assigns.default_form_data,
        filter_form: to_filter_form(socket.assigns.default_form_data),
        page: 0,
        has_more: true,
        loading: true,
        current_items_count: 0,
        total_items: 0,
        total_pages: 0,
        item_ids: [],
        item_id_set: MapSet.new()
      )
      |> stream(stream_atom, [], reset: true)
      |> notify_filters_change()

    {:noreply, load_next_page(socket)}
  end

  defp load_next_page(socket) do
    %{
      loader_mfa: {module, function, base_args},
      per_page: per_page,
      page: current_page,
      filters: filters
    } = socket.assigns

    next_page = current_page + 1

    args = base_args ++ [%{page: next_page, per_page: per_page, filters: filters}]

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
        assign(socket, loading: false, has_more: false)
    end
  rescue
    exception ->
      IO.inspect(exception, label: "Error loading data")
      IO.inspect(__STACKTRACE__, label: "Stacktrace")
      assign(socket, loading: false, has_more: false)
  end

  defp handle_load_result(socket, items, metadata) do
    stream_atom = socket.assigns.stream_atom
    existing_ids = socket.assigns.item_id_set

    {items_to_insert, updated_id_set} =
      Enum.reduce(items, {[], existing_ids}, fn item, {acc_items, id_set} ->
        if MapSet.member?(id_set, item.id) do
          {acc_items, id_set}
        else
          {[item | acc_items], MapSet.put(id_set, item.id)}
        end
      end)

    items_to_insert = Enum.reverse(items_to_insert)
    new_item_ids = socket.assigns.item_ids ++ Enum.map(items_to_insert, & &1.id)

    socket = stream_batch_insert(socket, stream_atom, items_to_insert)

    has_more =
      cond do
        Map.has_key?(metadata, :has_more) ->
          metadata.has_more

        Map.has_key?(metadata, :total_pages) ->
          metadata.page < metadata.total_pages

        true ->
          length(items) == socket.assigns.per_page
      end

    total_items = Map.get(metadata, :total_items, socket.assigns.total_items + length(items))
    current_items_count = MapSet.size(updated_id_set)

    socket =
      assign(socket,
        page: metadata.page,
        has_more: has_more,
        loading: false,
        item_ids: new_item_ids,
        item_id_set: updated_id_set,
        current_items_count: current_items_count,
        total_items: total_items,
        total_pages: Map.get(metadata, :total_pages, socket.assigns.total_pages)
      )

    maybe_sync_missing_items(socket)
  end

  defp maybe_sync_missing_items(socket) do
    cond do
      socket.assigns.has_more ->
        socket

      socket.assigns.current_items_count >= socket.assigns.total_items ->
        socket

      true ->
        sync_with_full_dataset(socket)
    end
  end

  defp handle_insert(socket, item) do
    matches_filters? =
      matches_filters?(item, socket.assigns.filters, socket.assigns.filter_config)

    stream_atom = socket.assigns.stream_atom
    id_set = socket.assigns.item_id_set

    cond do
      matches_filters? and MapSet.member?(id_set, item.id) ->
        socket
        |> handle_delete(item, decrement_total?: false)
        |> do_insert(item, stream_atom, increment_total?: false)

      matches_filters? ->
        do_insert(socket, item, stream_atom, increment_total?: true)

      MapSet.member?(id_set, item.id) ->
        handle_delete(socket, item, decrement_total?: true)

      true ->
        socket
    end
  end

  defp handle_delete(socket, item, opts \\ []) do
    stream_atom = socket.assigns.stream_atom
    id_set = socket.assigns.item_id_set

    if MapSet.member?(id_set, item.id) do
      new_ids = Enum.reject(socket.assigns.item_ids, &(&1 == item.id))
      decrement_total? = Keyword.get(opts, :decrement_total?, true)

      socket
      |> stream_delete(stream_atom, item)
      |> assign(
        item_ids: new_ids,
        item_id_set: MapSet.delete(id_set, item.id),
        current_items_count: length(new_ids),
        total_items:
          if(decrement_total?,
            do: max(socket.assigns.total_items - 1, 0),
            else: socket.assigns.total_items
          )
      )
    else
      socket
    end
  end

  defp do_insert(socket, item, stream_atom, opts) do
    increment_total? = Keyword.get(opts, :increment_total?, false)
    new_ids = [item.id | Enum.reject(socket.assigns.item_ids, &(&1 == item.id))]

    socket
    |> stream_insert(stream_atom, item, at: 0)
    |> assign(
      item_ids: new_ids,
      item_id_set: MapSet.put(socket.assigns.item_id_set, item.id),
      current_items_count: length(new_ids),
      total_items:
        if(increment_total?, do: socket.assigns.total_items + 1, else: socket.assigns.total_items)
    )
  end

  defp matches_filters?(_item, _filters, []), do: true

  defp matches_filters?(item, filters, config) do
    Enum.all?(config, fn field ->
      value = Map.get(filters, field.name)

      if value in [nil, ""] do
        true
      else
        matcher = Map.get(field, :match, fn entry, val -> Map.get(entry, field.name) == val end)

        try do
          matcher.(item, value)
        rescue
          _ -> false
        end
      end
    end)
  end

  defp stream_batch_insert(socket, _stream_atom, []), do: socket

  defp stream_batch_insert(socket, stream_atom, items) do
    Enum.reduce(items, socket, fn item, acc_socket ->
      stream_insert(acc_socket, stream_atom, item, at: -1)
    end)
  end

  defp sync_with_full_dataset(socket) do
    %{
      loader_mfa: {module, function, base_args},
      filters: filters,
      stream_atom: stream_atom,
      item_id_set: id_set,
      item_ids: item_ids
    } = socket.assigns

    args = base_args ++ [%{page: 1, per_page: :all, filters: filters}]

    case apply(module, function, args) do
      %{items: items} when is_list(items) ->
        total_items = length(items)
        per_page = socket.assigns.per_page
        total_pages =
          cond do
            per_page in [nil, :all] -> 1
            per_page > 0 -> div(total_items + per_page - 1, per_page)
            true -> socket.assigns.total_pages
          end

        {missing_items, updated_id_set} =
          Enum.reduce(items, {[], id_set}, fn item, {acc, set} ->
            if MapSet.member?(set, item.id) do
              {acc, set}
            else
              {[item | acc], MapSet.put(set, item.id)}
            end
          end)

        missing_items = Enum.reverse(missing_items)

        if missing_items == [] do
          assign(socket,
            current_items_count: MapSet.size(updated_id_set),
            total_items: max(socket.assigns.total_items, total_items),
            total_pages: total_pages
          )
        else
          new_item_ids = item_ids ++ Enum.map(missing_items, & &1.id)

          socket
          |> stream_batch_insert(stream_atom, missing_items)
          |> assign(
            item_ids: new_item_ids,
            item_id_set: updated_id_set,
            current_items_count: MapSet.size(updated_id_set),
            total_items: max(socket.assigns.total_items, total_items),
            total_pages: total_pages
          )
        end

      _ ->
        socket
    end
  rescue
    exception ->
      IO.inspect(exception, label: "Error syncing missing items")
      IO.inspect(__STACKTRACE__, label: "Stacktrace")
      socket
  end

  defp maybe_init_stream(socket) do
    stream(socket, socket.assigns.stream_atom, [])
  end

  defp maybe_init_filters(socket, assigns) do
    if socket.assigns.filters_initialized? do
      socket
    else
      config = socket.assigns.filter_config

      {default_filters, default_form_data} = build_default_filters(config)

      initial_filters =
        assigns
        |> Map.get(:initial_filters)
        |> normalize_filter_input(config)

      {filters, form_data} =
        config
        |> build_filter_state(Map.merge(default_filters, initial_filters))

      socket
      |> assign(
        filters_initialized?: true,
        default_filters: default_filters,
        default_form_data: default_form_data,
        filters: filters,
        filter_form_data: form_data,
        filter_form: to_filter_form(form_data)
      )
    end
  end

  defp build_default_filters(config) do
    defaults =
      Enum.reduce(config, %{}, fn field, acc ->
        Map.put(acc, field.name, Map.get(field, :default))
      end)

    build_filter_state(config, defaults)
  end

  defp build_filter_state(config, raw_values) do
    Enum.reduce(config, {%{}, %{}}, fn field, {typed_acc, form_acc} ->
      raw_value = Map.get(raw_values, field.name)
      parser = Map.get(field, :parser, &default_parser/1)
      to_form_value = Map.get(field, :to_form_value, &default_form_value/1)

      typed_value =
        try do
          parser.(raw_value)
        rescue
          _ -> nil
        end

      form_value =
        try do
          to_form_value.(typed_value)
        rescue
          _ -> nil
        end

      {
        Map.put(typed_acc, field.name, typed_value),
        Map.put(form_acc, field.name, form_value)
      }
    end)
  end

  defp parse_filters_from_params(config, params) do
    Enum.reduce(config, {%{}, %{}}, fn field, {typed_acc, form_acc} ->
      param_key = Atom.to_string(field.name)
      raw_value = Map.get(params, param_key)
      parser = Map.get(field, :parser, &default_parser/1)
      to_form_value = Map.get(field, :to_form_value, &default_form_value/1)

      typed_value =
        case raw_value do
          value when value in [nil, ""] ->
            nil

          value ->
            try do
              parser.(value)
            rescue
              _ -> nil
            end
        end

      form_value =
        case typed_value do
          nil ->
            nil

          value ->
            try do
              to_form_value.(value)
            rescue
              _ -> nil
            end
        end

      {
        Map.put(typed_acc, field.name, typed_value),
        Map.put(form_acc, field.name, form_value)
      }
    end)
  end

  defp normalize_filter_input(nil, _config), do: %{}

  defp normalize_filter_input(values, config) when is_map(values) do
    Enum.reduce(values, %{}, fn {key, value}, acc ->
      case find_field(config, key) do
        nil -> acc
        field -> Map.put(acc, field.name, value)
      end
    end)
  end

  defp normalize_filter_input(_, _config), do: %{}

  defp find_field(config, key) do
    cond do
      is_atom(key) -> Enum.find(config, fn field -> field.name == key end)
      is_binary(key) -> Enum.find(config, fn field -> Atom.to_string(field.name) == key end)
      true -> nil
    end
  end

  defp notify_filters_change(socket) do
    target = socket.assigns.filter_change_target
    message = socket.assigns.filter_change_message

    if target && message do
      send(target, {message, socket.assigns.filters})
    end

    socket
  end

  defp ensure_stream_atom(socket) do
    cond do
      Map.has_key?(socket.assigns, :stream_atom) ->
        socket

      true ->
        case socket.assigns[:stream_name] do
          name when is_atom(name) -> assign(socket, stream_atom: name)
          name when is_binary(name) -> assign(socket, stream_atom: String.to_atom(name))
          _ -> socket
        end
    end
  end

  defp default_parser(value), do: value

  defp default_form_value(nil), do: nil
  defp default_form_value(value) when is_binary(value), do: value
  defp default_form_value(value), do: to_string(value)

  defp to_filter_form(nil), do: to_filter_form(%{})

  defp to_filter_form(form_data) when is_map(form_data) do
    params =
      Enum.reduce(form_data, %{}, fn {key, value}, acc ->
        Map.put(acc, form_key_to_string(key), value)
      end)

    Phoenix.Component.to_form(params, as: :filter)
  end

  defp form_key_to_string(key) when is_atom(key), do: Atom.to_string(key)
  defp form_key_to_string(key), do: key

  defp filters_active?(form_data) do
    form_data
    |> Map.values()
    |> Enum.any?(fn value ->
      cond do
        value in [nil, "", []] -> false
        is_map(value) -> value != %{}
        true -> true
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={@wrapper_class || ""}>
      <%= if @filter_config != [] do %>
        <details
          class="group rounded-2xl border border-base-300 bg-base-100/80 mb-4 shadow-sm"
          open={if filters_active?(@filter_form_data), do: true, else: nil}
        >
          <summary class="flex items-center justify-between gap-4 px-5 py-4 cursor-pointer select-none font-semibold">
            <span class="flex items-center gap-2">
              <.icon name="hero-funnel" />
              <%= gettext("Filters") %>
            </span>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 transition-transform duration-200 group-open:rotate-180"
            />
          </summary>
          <div class="border-t border-base-300/60 bg-base-100 px-5 py-5 rounded-b-2xl">
            <.form
              for={@filter_form}
              phx-submit="apply_filters"
              phx-target={@myself}
              class="flex flex-col gap-6"
            >
              <div class="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
                <%= for field <- @filter_config do %>
                  <% current_value = Map.get(@filter_form_data, field.name) %>
                  <.input
                    field={@filter_form[field.name]}
                    type={field.type}
                    label={field.label}
                    options={Map.get(field, :options)}
                    prompt={Map.get(field, :prompt)}
                    value={current_value}
                    class="w-full"
                  />
                <% end %>
              </div>

              <div class="flex flex-col gap-2 sm:flex-row sm:justify-end sm:items-center">
                <.button type="submit" variant="primary" class="w-full sm:w-auto">
                  <.icon name="hero-funnel" /> <%= gettext("Apply filters") %>
                </.button>
                <.button
                  type="button"
                  variant="custom"
                  phx-click="reset_filters"
                  phx-target={@myself}
                  class="w-full sm:w-auto"
                >
                  <.icon name="hero-x-mark" /> <%= gettext("Clear filters") %>
                </.button>
              </div>
            </.form>
          </div>
        </details>
      <% end %>

      <%= if @total_items > 0 do %>
        <div class="flex flex-wrap justify-between items-center text-sm text-base-content/70 mb-2 px-4 py-2 rounded-xl bg-base-200/60">
          <span>
            <%=
              gettext(
                "Loaded %{current} of %{total}",
                current: @current_items_count,
                total: @total_items
              )
            %>
          </span>
          <span>
            <%= gettext("Page %{page}/%{total}", page: @page, total: @total_pages) %>
          </span>
        </div>
      <% end %>

      {render_slot(@content, @streams[@stream_atom])}

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
          <div class="text-center py-6 text-base-content/60 text-sm">
            <%= if @current_items_count == 0 do %>
              <%= gettext("No items found") %>
            <% else %>
              <%= gettext("All items loaded") %>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
