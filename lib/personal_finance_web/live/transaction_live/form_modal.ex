defmodule PersonalFinanceWeb.TransactionLive.FormModal do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Transaction

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       form:
         to_form(
           Finance.change_transaction(
             assigns.current_scope,
             assigns.transaction || %Transaction{budget_id: assigns.budget.id},
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
            Editar Transação
          <% else %>
            Nova Transação
          <% end %>
        </h2>

        <.link class="text-red-600 hover:text-red-800 hero-x-mark" phx-click="close_form"></.link>
      </div>

      <.form
        id="transaction-form"
        for={@form}
        phx-submit="save"
        phx-change="validate"
        phx-target={@myself}
        class="flex flex-col gap-4"
      >
        <.input
          field={@form[:description]}
          id="input-description"
          type="text"
          label="Descrição"
          placeholder="Ex: Monster"
        />

        <.input
          field={@form[:profile_id]}
          id="input-profile"
          type="select"
          options={@profiles}
          label="Perfil"
        />

        <.input
          field={@form[:category_id]}
          id="input-category"
          type="select"
          options={@categories}
          label="Categoria"
        />

        <%= if @selected_category_id && to_string(@selected_category_id) == to_string(@investment_category_id) do %>
          <.input
            field={@form[:investment_type_id]}
            id="input-investment-type"
            type="select"
            options={@investment_types}
            label="Tipo de Investimento"
          />
        <% end %>

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

        <.input
          field={@form[:date]}
          id="input-date"
          type="date"
          label="Data"
          placeholder="Ex: 2023-10-01"
        />

        <.button variant="primary" phx-disable-with="Salvando">
          <.icon name="hero-check" /> Salvar Transação
        </.button>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("save", %{"transaction" => transaction_params}, socket) do
    save_transaction(socket, socket.assigns.action, transaction_params)
  end

  @impl true
  def handle_event("validate", %{"transaction" => transaction_params}, socket) do
    value = Map.get(transaction_params, "value") |> parse_float()
    amount = Map.get(transaction_params, "amount") |> parse_float()
    total_value = value * amount
    params = Map.put(transaction_params, "total_value", total_value)

    new_selected_category_id =
      Map.get(transaction_params, "category_id") || socket.assigns.selected_category_id

    changeset =
      Finance.change_transaction(
        socket.assigns.current_scope,
        socket.assigns.transaction,
        socket.assigns.budget,
        params
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate),
       selected_category_id: new_selected_category_id
     )}
  end

  defp save_transaction(socket, :edit, transaction_params) do
    value = Map.get(transaction_params, "value") |> parse_float()
    amount = Map.get(transaction_params, "amount") |> parse_float()
    total_value = value * amount

    transaction_params =
      if String.to_integer(transaction_params["category_id"]) !=
           socket.assigns.investment_category_id do
        Map.put(transaction_params, "investment_type_id", nil)
      else
        transaction_params
      end

    transaction_params = Map.put(transaction_params, "total_value", total_value)

    case Finance.update_transaction(
           socket.assigns.current_scope,
           socket.assigns.transaction,
           transaction_params
         ) do
      {:ok, transaction} ->
        send(socket.assigns.parent_pid, {:transaction_saved, transaction})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_transaction(socket, :new, transaction_params) do
    value = Map.get(transaction_params, "value") |> parse_float()
    amount = Map.get(transaction_params, "amount") |> parse_float()
    total_value = value * amount

    case Finance.create_transaction(
           socket.assigns.current_scope,
           Map.put(transaction_params, "total_value", total_value),
           socket.assigns.budget
         ) do
      {:ok, transaction} ->
        send(socket.assigns.parent_pid, {:transaction_saved, transaction})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Transaction Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {number, _} -> number
      :error -> 0.0
    end
  end

  defp parse_float(_), do: 0.0
end
