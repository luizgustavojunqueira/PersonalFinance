defmodule PersonalFinanceWeb.CategoryLive.FormModal do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Finance

  @impl true
  def update(assigns, socket) do
    IO.inspect(socket)
    IO.inspect(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       form:
         to_form(
           Finance.change_category(
             assigns.current_scope,
             assigns.category,
             assigns.budget
           )
         )
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex flex-row justify-between mb-5 items-center">
        <h2 class="text-2xl font-semibold mb-4 ">
          <%= if @action == :edit do %>
            Editar Categoria
          <% else %>
            Nova Categoria
          <% end %>
        </h2>

        <.link class="text-red-600 hover:text-red-800 hero-x-mark" phx-click="close_form"></.link>
      </div>

      <.form
        id="category-form"
        for={@form}
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
        class="flex flex-col gap-4"
      >
        <.input
          field={@form[:name]}
          id="input-name"
          type="text"
          label="Nome"
          placeholder="Ex: Alimentação"
          required
        />
        <.input
          field={@form[:description]}
          id="input-description"
          type="text"
          label="Descrição"
          placeholder="Ex: Despesas com alimentação"
          required
        />

        <.input
          field={@form[:percentage]}
          id="input-percentage"
          type="number"
          step="0.01"
          label="Porcentagem"
          placeholder="Ex: 10.00"
        />

        <.button variant="primary" phx-disable-with="Salvando">
          <.icon name="hero-check" /> Salvar Categoria
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("save", %{"category" => category_params}, socket) do
    save_category(socket, socket.assigns.action, category_params)
  end

  @impl true
  def handle_event("validate", %{"category" => category_params}, socket) do
    changeset =
      Finance.change_category(
        socket.assigns.current_scope,
        socket.assigns.category,
        socket.assigns.budget,
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
      {:ok, category} ->
        IO.inspect(category, label: "Category Saved in Form Modal")
        send(socket.assigns.parent_pid, {:category_saved, category})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_category(socket, :new, category_params) do
    case Finance.create_category(
           socket.assigns.current_scope,
           category_params,
           socket.assigns.budget
         ) do
      {:ok, category} ->
        send(socket.assigns.parent_pid, {:category_saved, category})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Category Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
