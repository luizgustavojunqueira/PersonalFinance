defmodule PersonalFinanceWeb.FixedIncomeLive.Details.Form do
  alias PersonalFinance.Investment
  alias PersonalFinance.Investment.{FixedIncomeTransaction}

  use PersonalFinanceWeb, :live_component

  @impl true
  def update(assigns, socket) do
    ledger = assigns.ledger
    fixed_income = assigns.fixed_income || %FixedIncomeTransaction{ledger_id: ledger.id}

    changeset =
      Investment.change_fixed_income_transaction(
        %FixedIncomeTransaction{},
        fixed_income,
        ledger,
        %{},
        fixed_income.profile_id
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(form: to_form(changeset, as: :fixed_income_transaction))

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
        <:title>Cadastrar Transação</:title>
        <.form
          for={@form}
          id="fixed-income-form"
          phx-submit="save"
          phx-change="validate"
          phx-target={@myself}
        >
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <.input
              field={@form[:description]}
              type="text"
              label="Descrição"
              required
            />

            <.input
              field={@form[:type]}
              type="select"
              label="Tipo"
              options={[{"Depósito", :deposit}, {"Resgate", :withdraw}]}
            />

            <.input
              field={@form[:value]}
              type="number"
              label="Valor (R$)"
              required
              autocomplete="off"
            />
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
  def handle_event("validate", %{"fixed_income_transaction" => fi_params}, socket) do
    changeset =
      Investment.change_fixed_income_transaction(
        %FixedIncomeTransaction{},
        socket.assigns.fixed_income,
        socket.assigns.ledger,
        fi_params,
        socket.assigns.fixed_income.profile_id
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"fixed_income_transaction" => fi_params}, socket) do
    case Investment.create_transaction(
           socket.assigns.fixed_income,
           fi_params,
           socket.assigns.ledger,
           socket.assigns.fixed_income.profile_id
         ) do
      {:ok, _fi_transaction} ->
        {:noreply, assign(socket, show: false)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
