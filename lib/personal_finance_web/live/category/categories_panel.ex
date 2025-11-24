defmodule PersonalFinanceWeb.CategoryLive.CategoriesPanel do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Finance
  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:open_modal, nil)
     |> assign(:category, nil)
     |> assign(:initialized?, false)
     |> assign(:categories, [])
     |> stream(:category_collection, [])}
  end

  @impl true
  def update(%{action: :saved, category: _category}, socket) do
    {:ok,
     socket
     |> assign(:open_modal, nil)
     |> assign(:category, nil)
     |> reload_categories()}
  end

  def update(%{action: :deleted, category: _category}, socket) do
    {:ok, reload_categories(socket)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> maybe_initialize_categories()}
  end

  @impl true
  def handle_event("open_edit_category", %{"category_id" => id}, socket) do
    category =
      Finance.get_category(socket.assigns.current_scope, id, socket.assigns.ledger)

    if category do
      {:noreply, assign(socket, open_modal: :edit_category, category: category)}
    else
      {:noreply, put_flash(socket, :error, gettext("Category not found."))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    category = Finance.get_category(current_scope, id, socket.assigns.ledger)

    case Finance.delete_category(current_scope, category) do
      {:ok, _deleted} ->
        {:noreply,
         socket
         |> assign(open_modal: nil, category: nil)
         |> reload_categories()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete category."))}
    end
  end

  def handle_event("open_modal", %{"modal" => modal}, socket) do
    {:noreply, assign(socket, open_modal: String.to_existing_atom(modal), category: nil)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, open_modal: nil, category: nil)}
  end

  def handle_event("open_delete_modal", %{"category_id" => category_id}, socket) do
    category =
      Finance.get_category(socket.assigns.current_scope, category_id, socket.assigns.ledger)

    if category do
      {:noreply, assign(socket, open_modal: :delete_category, category: category)}
    else
      {:noreply, put_flash(socket, :error, gettext("Category not found."))}
    end
  end

  def handle_event(
        "update_percentage",
        %{"category_id" => category_id, "percentage" => value},
        socket
      ) do
    with {:ok, category} <- fetch_category(socket, category_id, socket.assigns.ledger),
         false <- slider_disabled?(category),
         {:ok, parsed_value} <- parse_percentage(value),
         {:ok, _category} <-
           Finance.update_category(
             socket.assigns.current_scope,
             category,
             %{percentage: parsed_value}
           ) do
      {:noreply, reload_categories(socket)}
    else
      true ->
        {:noreply, socket}

      {:error, :invalid_value} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Invalid value for percentage."))
         |> reload_categories()}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Category not found."))
         |> reload_categories()}

      {:error, %Ecto.Changeset{} = changeset} ->
        message = percentage_error_message(changeset)

        {:noreply,
         socket
         |> put_flash(:error, message)
         |> reload_categories()}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-6">
      <div class="flex items-center justify-between">
        <h2 class="text-2xl font-semibold">{gettext("Categories")}</h2>
        <.button
          variant="primary"
          phx-target={@myself}
          phx-click="open_modal"
          phx-value-modal={:new_category}
        >
          <.icon name="hero-plus" /> {gettext("Add Category")}
        </.button>
      </div>

      <.live_component
        module={PersonalFinanceWeb.CategoryLive.CategoryForm}
        id={"#{@id}-form"}
        show={@open_modal in [:new_category, :edit_category]}
        action={if @open_modal == :new_category, do: :new, else: :edit}
        category={@category}
        ledger={@ledger}
        current_scope={@current_scope}
        close_target={@myself}
      />

      <.modal
        id={"#{@id}-delete"}
        show={@open_modal == :delete_category}
        on_close={JS.push("close_modal", target: @myself)}
        class="mt-2"
      >
        <:title>{gettext("Delete Category")}</:title>
        {gettext("Are you sure you want to delete the category \"%{name}\"?",
          name: @category && @category.name
        )}
        <:actions>
          <.button
            variant="primary"
            phx-target={@myself}
            phx-click="delete"
            phx-value-id={@category && @category.id}
          >
            {gettext("Delete")}
          </.button>
          <.button phx-target={@myself} phx-click="close_modal">
            {gettext("Cancel")}
          </.button>
        </:actions>
      </.modal>

      <.table
        id={"#{@id}-table"}
        rows={@streams.category_collection}
        col_widths={["20%", "25%", "10%", "10%"]}
        row_item={
          fn
            {_, struct} -> struct
            struct -> struct
          end
        }
      >
        <:col :let={category} label={gettext("Name")}>
          <.text_ellipsis text={category.name} max_width="max-w-[15rem]" />
        </:col>
        <:col :let={category} label={gettext("Description")}>
          <.text_ellipsis text={category.description} max_width="max-w-[20rem]" />
        </:col>
        <:col :let={category} label={gettext("Color")}>
          <span
            class="inline-block w-7 h-4 rounded-xl border-2 border-black dark:border-white"
            style={"background-color: #{category.color};"}
          >
          </span>
        </:col>
        <:col :let={category} label={gettext("Percentage (100% max.)")}>
          <%= if slider_disabled?(category) do %>
            <div class="flex items-center gap-4 text-sm">
              <span class="font-semibold tabular-nums w-16 text-right">
                {format_percentage(category.percentage)}
              </span>
              <span class="text-xs uppercase tracking-wide text-zinc-400 dark:text-zinc-500">
                {gettext("Locked")}
              </span>
            </div>
          <% else %>
            <form
              phx-submit="update_percentage"
              phx-target={@myself}
              class="flex items-center gap-4"
            >
              <input type="hidden" name="category_id" value={category.id} />
              <span class="text-sm font-semibold tabular-nums w-16 text-right">
                {format_percentage(category.percentage)}
              </span>
              <div class="slider-shell relative">
                <input
                  type="range"
                  id={"category-slider-#{category.id}"}
                  name="percentage"
                  class="category-slider"
                  min="0"
                  max="100"
                  step="0.5"
                  value={category.percentage}
                  phx-hook="RangeField"
                  data-max-available={percentage_slider_max(@categories, category)}
                  aria-label={gettext("Category percentage %{name}", name: category.name)}
                  style={slider_style(@categories, category)}
                />
              </div>
            </form>
          <% end %>
        </:col>
        <:action :let={category}>
          <%= if !category.is_default do %>
            <.link
              phx-target={@myself}
              phx-click="open_edit_category"
              phx-value-category_id={category.id}
            >
              <.icon name="hero-pencil" class="text-blue-500 hover:text-blue-800" />
            </.link>
          <% end %>
        </:action>
        <:action :let={category}>
          <%= if !category.is_fixed do %>
            <.link
              phx-target={@myself}
              phx-click="open_delete_modal"
              phx-value-category_id={category.id}
            >
              <.icon name="hero-trash" class="text-red-600 hover:text-red-800" />
            </.link>
          <% end %>
        </:action>
      </.table>
    </div>
    """
  end

  defp maybe_initialize_categories(socket) do
    if socket.assigns.initialized? do
      socket
    else
      socket
      |> assign(:initialized?, true)
      |> reload_categories()
    end
  end

  defp reload_categories(socket) do
    categories = Finance.list_categories(socket.assigns.current_scope, socket.assigns.ledger)

    socket
    |> assign(:categories, categories)
    |> stream(:category_collection, categories, reset: true)
  end

  defp fetch_category(socket, category_id, ledger) do
    case Finance.get_category(socket.assigns.current_scope, category_id, ledger) do
      nil -> {:error, :not_found}
      category -> {:ok, category}
    end
  end

  defp slider_disabled?(category), do: category.is_default || category.is_fixed

  defp parse_percentage(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _rest} -> {:ok, Float.round(float, 2)}
      :error -> {:error, :invalid_value}
    end
  end

  defp parse_percentage(value) when is_float(value), do: {:ok, Float.round(value, 2)}

  defp parse_percentage(value) when is_integer(value) do
    {:ok, (value * 1.0) |> Float.round(2)}
  end

  defp percentage_error_message(%Ecto.Changeset{} = changeset) do
    case Keyword.get(changeset.errors, :percentage) do
      {message, _opts} -> message
      _ -> gettext("Unable to update the percentage.")
    end
  end

  defp percentage_slider_max(categories, category) do
    others_total =
      categories
      |> Enum.reject(&(&1.id == category.id))
      |> Enum.reduce(0.0, fn cat, acc -> acc + (cat.percentage || 0.0) end)

    remaining = 100.0 - others_total
    allowance = max(remaining, 0.0)

    allowance
    |> max(category.percentage || 0.0)
    |> Float.round(2)
  end

  defp slider_progress(category) do
    progress = category.percentage || 0.0
    progress |> min(100.0) |> max(0.0)
  end

  defp slider_style(_categories, category) do
    progress = slider_progress(category)

    "--slider-progress: #{progress}%; --slider-primary: var(--color-primary); --slider-track: #ffffff;"
  end

  defp format_percentage(nil), do: "0.00%"

  defp format_percentage(value) do
    formatted =
      value
      |> Float.round(2)
      |> :erlang.float_to_binary(decimals: 2)

    formatted <> "%"
  end
end
