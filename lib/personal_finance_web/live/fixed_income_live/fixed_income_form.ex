defmodule PersonalFinanceWeb.FixedIncomeLive.FixedIncomeForm do
  alias PersonalFinance.Investment
  alias PersonalFinance.Investment.{FixedIncome}

  use PersonalFinanceWeb, :live_component

  @impl true
  def update(assigns, socket) do
    ledger = assigns.ledger

    fixed_income =
      assigns.fixed_income ||
        %FixedIncome{ledger_id: ledger.id}

    changeset =
      Investment.change_fixed_income(
        fixed_income,
        ledger,
        %{},
        1
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(form: to_form(changeset, as: :fixed_income))

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
        <:title>{if @action == :edit, do: "Editar Renda Fixa", else: "Nova Renda Fixa"}</:title>
        <.form
          for={@form}
          id="fixed-income-form"
          phx-submit="save"
          phx-change="validate"
          phx-target={@myself}
        >
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <.input
                field={@form[:name]}
                type="text"
                label="Nome"
                required
              />
            </div>

            <div>
              <.input
                field={@form[:institution]}
                type="text"
                label="Instituição"
              />
            </div>

            <div>
              <.input
                field={@form[:type]}
                type="select"
                label="Tipo"
                options={[{"CDB", :cdb}]}
              />
            </div>

            <div>
              <.input
                field={@form[:remuneration_basis]}
                type="select"
                label="Base de Remuneração"
                options={[{"CDI", :cdi}]}
              />
            </div>

            <div>
              <.input
                field={@form[:initial_investment]}
                type="number"
                label="Valor (R$)"
                required
                autocomplete="off"
              />
            </div>

            <div>
              <.input
                field={@form[:remuneration_rate]}
                type="number"
                label="Taxa de Remuneração (%)"
                step="0.01"
                min="0"
                required
              />
            </div>

            <div>
              <.input
                field={@form[:start_date]}
                type="date"
                label="Data"
                required
              />
            </div>

            <div>
              <.input
                field={@form[:yield_frequency]}
                type="select"
                label="Frequência de Rentabilidade"
                options={[
                  {"Diária", :daily},
                  {"Mensal", :monthly},
                  {"Trimestral", :quarterly},
                  {"Semestral", :semiannual},
                  {"Anual", :annual},
                  {"No Vencimento", :at_maturity}
                ]}
              />
            </div>
          </div>

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
  def handle_event("validate", %{"fixed_income" => fixed_income_params}, socket) do
    changeset =
      Investment.change_fixed_income(
        socket.assigns.fixed_income || %FixedIncome{ledger_id: socket.assigns.ledger.id},
        socket.assigns.ledger,
        fixed_income_params,
        1
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate)
     )}
  end

  @impl true
  def handle_event("save", %{"fixed_income" => fixed_income_params}, socket) do
    case Investment.create_fixed_income(fixed_income_params, socket.assigns.ledger, 1) do
      {:ok, fixed_income} ->
        send(self(), {:saved, fixed_income})
        {:noreply, assign(socket, show: false)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
