defmodule PersonalFinanceWeb.TransactionLive.Filter do
  alias PersonalFinance.Utils.ParseUtils
  use PersonalFinanceWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(
        profiles: assigns.profiles || [],
        categories: assigns.categories || [],
        investment_types: assigns.investment_types || [],
        form: to_form(assigns.filter, as: :filter)
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter_params}, socket) do
    filter = %{
      "profile_id" => ParseUtils.parse_id(filter_params["profile_id"]),
      "type" => ParseUtils.parse_text(filter_params["type"]),
      "category_id" => ParseUtils.parse_id(filter_params["category_id"]),
      "investment_type_id" => ParseUtils.parse_id(filter_params["investment_type_id"]),
      "start_date" => ParseUtils.parse_text(filter_params["start_date"]),
      "end_date" => ParseUtils.parse_text(filter_params["end_date"])
    }

    send(socket.assigns.parent_pid, {:apply_filter, filter})

    {:noreply,
     socket
     |> assign(form: to_form(filter, as: :filter))}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    filter = %{
      "profile_id" => nil,
      "type" => nil,
      "category_id" => nil,
      "investment_type_id" => nil,
      "start_date" => nil,
      "end_date" => nil
    }

    send(socket.assigns.parent_pid, {:apply_filter, filter})

    {:noreply,
     socket
     |> assign(form: to_form(filter, as: :filter))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <details
      phx-mounted={JS.ignore_attributes(["open"])}
      class="collapse bg-base-300 "
      id="filter-collapse"
    >
      <summary class="collapse-title font-semibold">
        <.icon name="hero-funnel" class="inline-block mr-2" /> Filtros
      </summary>
      <div class="collapse-content text-sm">
        <.form for={@form} phx-submit="filter" phx-target={@myself} class="flex flex-col gap-4">
          <div class="flex flex-col gap-2">
            <div class="flex flex-row gap-2">
              <.input
                field={@form[:profile_id]}
                id="filter-profile"
                type="select"
                options={@profiles}
                label="Perfil"
                prompt="Selecione um perfil"
              />

              <.input
                field={@form[:type]}
                id="filter-type"
                type="select"
                label="Tipo"
                options={[{"Receita", :income}, {"Despesa", :expense}]}
                prompt="Selecione um tipo"
              />

              <.input
                field={@form[:category_id]}
                id="filter-category"
                type="select"
                options={@categories}
                label="Categoria"
                prompt="Selecione uma categoria"
              />

              <.input
                field={@form[:investment_type_id]}
                id="filter-investment-type"
                type="select"
                options={@investment_types}
                label="Tipo de Investimento"
                prompt="Selecione um tipo de investimento"
              />
            </div>

            <div class="flex flex-row gap-2">
              <.input
                field={@form[:start_date]}
                id="filter-start-date"
                type="date"
                label="Data Inicial"
                placeholder="Ex: 2023-10-01"
              />

              <.input
                field={@form[:end_date]}
                id="filter-end-date"
                type="date"
                label="Data Final"
                placeholder="Ex: 2023-10-31"
              />
            </div>
          </div>
          <div class="flex flex-row justify-end">
            <.button type="submit" variant="primary">
              <.icon name="hero-funnel" /> Aplicar Filtros
            </.button>
            <.button
              type="button"
              variant="custom"
              phx-target={@myself}
              phx-click="reset_filters"
              class="ml-2"
            >
              <.icon name="hero-x-mark" /> Limpar Filtros
            </.button>
          </div>
        </.form>
      </div>
    </details>
    """
  end
end
