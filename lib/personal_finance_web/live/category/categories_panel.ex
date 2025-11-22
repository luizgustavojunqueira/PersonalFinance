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
     |> stream(:category_collection, [])}
  end

  @impl true
  def update(%{action: :saved, category: category}, socket) do
    {:ok,
     socket
     |> stream_insert(:category_collection, category)
     |> assign(:open_modal, nil)
     |> assign(:category, nil)}
  end

  def update(%{action: :deleted, category: category}, socket) do
    {:ok, stream_delete(socket, :category_collection, category)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> maybe_initialize_categories(assigns)}
  end

  @impl true
  def handle_event("open_edit_category", %{"category_id" => id}, socket) do
    category =
      Finance.get_category(socket.assigns.current_scope, id, socket.assigns.ledger)

    if category do
      {:noreply, assign(socket, open_modal: :edit_category, category: category)}
    else
      {:noreply, put_flash(socket, :error, "Categoria não encontrada.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    category = Finance.get_category(current_scope, id, socket.assigns.ledger)

    case Finance.delete_category(current_scope, category) do
      {:ok, _deleted} ->
        {:noreply, assign(socket, open_modal: nil, category: nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao remover categoria.")}
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
      {:noreply, put_flash(socket, :error, "Categoria não encontrada.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-6">
      <div class="flex items-center justify-between">
        <h2 class="text-2xl font-semibold">Categorias</h2>
        <.button
          variant="primary"
          phx-target={@myself}
          phx-click="open_modal"
          phx-value-modal={:new_category}
        >
          <.icon name="hero-plus" /> Adicionar Categoria
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
        <:title>Excluir Categoria</:title>
        Tem certeza de que deseja excluir a categoria "{@category && @category.name}"?
        <:actions>
          <.button
            variant="primary"
            phx-target={@myself}
            phx-click="delete"
            phx-value-id={@category && @category.id}
          >
            Excluir
          </.button>
          <.button phx-target={@myself} phx-click="close_modal">
            Cancelar
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
        <:col :let={category} label="Nome">
          <.text_ellipsis text={category.name} max_width="max-w-[15rem]" />
        </:col>
        <:col :let={category} label="Descrição">
          <.text_ellipsis text={category.description} max_width="max-w-[20rem]" />
        </:col>
        <:col :let={category} label="Cor">
          <span
            class="inline-block w-7 h-4 rounded-xl border-2 border-black dark:border-white"
            style={"background-color: #{category.color};"}
          >
          </span>
        </:col>
        <:col :let={category} label="Porcentagem">
          {category.percentage}
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

  defp maybe_initialize_categories(socket, assigns) do
    if socket.assigns.initialized? do
      socket
    else
      categories = Finance.list_categories(assigns.current_scope, assigns.ledger)

      socket
      |> assign(:initialized?, true)
      |> stream(:category_collection, categories, reset: true)
    end
  end
end
