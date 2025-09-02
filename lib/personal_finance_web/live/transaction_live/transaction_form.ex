defmodule PersonalFinanceWeb.TransactionLive.TransactionForm do
  use PersonalFinanceWeb, :live_component
  alias PersonalFinance.Utils.ParseUtils
  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Transaction

  @impl true
  def update(assigns, socket) do
    ledger = assigns.ledger
    current_scope = assigns.current_scope

    transaction =
      assigns.transaction || %Transaction{ledger_id: ledger.id, date: Date.utc_today()}

    changeset =
      Finance.change_transaction(
        current_scope,
        transaction,
        ledger,
        %{}
      )

    formatted_value = ParseUtils.format_float_for_input(changeset.data.value)
    formatted_amount = ParseUtils.format_float_for_input(changeset.data.amount)

    changeset =
      changeset
      |> Ecto.Changeset.put_change(:value, formatted_value)
      |> Ecto.Changeset.put_change(:amount, formatted_amount)

    investment_category = Finance.get_investment_category(current_scope, ledger.id)

    socket =
      socket
      |> assign(assigns)
      |> assign(
        form: to_form(changeset, as: :transaction),
        selected_category_id: assigns.transaction && assigns.transaction.category_id,
        investment_category_id: if(investment_category, do: investment_category.id, else: nil)
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"transaction" => transaction_params}, socket) do
    value = Map.get(transaction_params, "value") |> ParseUtils.parse_float()
    amount = Map.get(transaction_params, "amount") |> ParseUtils.parse_float()
    total_value = value * amount

    params =
      Map.put(transaction_params, "total_value", total_value)

    new_selected_category_id =
      Map.get(transaction_params, "category_id") || socket.assigns.selected_category_id

    changeset =
      Finance.change_transaction(
        socket.assigns.current_scope,
        socket.assigns.transaction || %Transaction{ledger_id: socket.assigns.ledger.id},
        socket.assigns.ledger,
        params
      )
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket,
       form: to_form(changeset, as: :transaction),
       selected_category_id: new_selected_category_id
     )}
  end

  @impl true
  def handle_event("save", %{"transaction" => transaction_params}, socket) do
    value = Map.get(transaction_params, "value") |> ParseUtils.parse_float()
    amount = Map.get(transaction_params, "amount") |> ParseUtils.parse_float()
    total_value = value * amount
    params = Map.put(transaction_params, "total_value", total_value)

    action = socket.assigns.action

    case save_transaction(socket, action, params) do
      {:ok, transaction} ->
        send(self(), {:saved, transaction})
        {:noreply, assign(socket, show: false)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :transaction))}
    end
  end

  defp save_transaction(socket, :new, params) do
    Finance.create_transaction(
      socket.assigns.current_scope,
      params,
      socket.assigns.ledger
    )
  end

  defp save_transaction(socket, :edit, params) do
    Finance.update_transaction(
      socket.assigns.current_scope,
      socket.assigns.transaction,
      params
    )
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
        <:title>{if @action == :edit, do: "Editar Transação", else: "Nova Transação"}</:title>
        <.form
          for={@form}
          id="transaction-form"
          phx-submit="save"
          phx-change="validate"
          phx-target={@myself}
        >
          <.input
            field={@form[:description]}
            id="input-description"
            type="text"
            label="Descrição"
            placeholder="Ex: Monster"
          />
          <div class="flex flex-row gap-2">
            <.input
              field={@form[:profile_id]}
              id="input-profile"
              type="select"
              options={@profiles}
              label="Perfil"
            />
            <.input
              field={@form[:type]}
              id="input-type"
              type="select"
              label="Tipo"
              options={[{"Receita", :income}, {"Despesa", :expense}]}
            />
          </div>
          <div class="flex flex-row gap-2 transition-all">
            <.input
              field={@form[:category_id]}
              id="input-category"
              type="select"
              options={@categories}
              label="Categoria"
            />
            <%= if @selected_category_id && to_string(@selected_category_id) == to_string(@investment_category_id) do %>
              <div
                class="w-full"
                phx-mounted={
                  JS.transition(
                    {"transition-all transform ease-in", "opacity-0 max-w-0",
                     "opacity-100 max-w-full"},
                    time: 200
                  )
                }
                phx-remove={
                  JS.hide(
                    transition:
                      {"transition-all transform ease-in duration-200", "opacity-100 max-w-full",
                       "opacity-0 max-w-0"}
                  )
                }
              >
                <.input
                  field={@form[:investment_type_id]}
                  id="input-investment-type"
                  type="select"
                  options={@investment_types}
                  label="Tipo de Investimento"
                />
              </div>
            <% end %>
          </div>
          <div class="flex flex-row gap-2">
            <.input
              field={@form[:amount]}
              id="input-amount"
              type="number"
              step="0.00000001"
              label="Quantidade"
              placeholder="Ex: 1"
            />
            <.input
              field={@form[:value]}
              id="input-value"
              type="number"
              step="0.01"
              label="Valor"
              placeholder="Ex: 10.00"
            />
          </div>
          <.input
            field={@form[:date]}
            id="input-date"
            type="date"
            label="Data"
            placeholder="Ex: 2023-10-01"
          />
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
end
