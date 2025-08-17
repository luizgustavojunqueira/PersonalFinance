defmodule PersonalFinanceWeb.CategoryLive.CategoryForm do
  alias PersonalFinance.Finance.Category
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_component

  @impl true
  def update(assigns, socket) do
    ledger = assigns.ledger
    current_scope = assigns.current_scope

    category =
      assigns.category || %Category{ledger_id: ledger.id}

    changeset =
      Finance.change_category(
        current_scope,
        category,
        ledger,
        %{}
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(form: to_form(changeset, as: :category))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal
        show={@show}
        id={@id}
        on_close={JS.push("close_modal")}
        class="mt-2"
      >
        <:title>{if @action == :edit, do: "Editar Categoria", else: "Nova Categoria"}</:title>
        <.form
          for={@form}
          id="category-form"
          phx-submit="save"
          phx-change="validate"
          phx-target={@myself}
        >
          <.input
            field={@form[:name]}
            type="text"
            label="Nome"
            disabled={@category != nil and @category.is_fixed}
          />
          <.input
            field={@form[:description]}
            type="text"
            label="Descrição"
            disabled={@category != nil and @category.is_fixed}
          />
          <.input field={@form[:percentage]} type="number" label="Porcentagem" />
          <.input field={@form[:color]} type="color" label="Cor" />

          <div class="flex justify-center gap-2 mt-4">
            <.button
              variant="custom"
              class="btn btn-primary w-full"
              phx-disable-with="Salvando..."
            >
              Salvar
            </.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"category" => category_params}, socket) do
    changeset =
      Finance.change_category(
        socket.assigns.current_scope,
        socket.assigns.category || %Category{ledger_id: socket.assigns.ledger.id},
        socket.assigns.ledger,
        category_params
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate)
     )}
  end

  @impl true
  def handle_event("save", %{"category" => category_params}, socket) do
    case save_category(socket, socket.assigns.action, category_params) do
      {:ok, category} ->
        send(self(), {:saved, category})
        {:noreply, assign(socket, show: false)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_category(socket, :new, category_params) do
    Finance.create_category(
      socket.assigns.current_scope,
      category_params,
      socket.assigns.ledger
    )
  end

  defp save_category(socket, :edit, category_params) do
    Finance.update_category(
      socket.assigns.current_scope,
      socket.assigns.category,
      category_params
    )
  end
end

