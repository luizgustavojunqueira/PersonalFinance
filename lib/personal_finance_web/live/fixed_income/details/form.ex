defmodule PersonalFinanceWeb.FixedIncomeLive.Details.Form do
  alias PersonalFinance.Investment
  alias PersonalFinance.Investment.{FixedIncomeTransaction}
  alias PersonalFinance.Utils.CurrencyUtils

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
        <:title>{gettext("Create transaction")}</:title>
        <.form
          for={@form}
          id="fixed-income-form"
          phx-submit="save"
          phx-change="validate"
          phx-target={@myself}
        >
          <div class="space-y-5">
            <div class="rounded-2xl border border-base-300 bg-base-100/80 p-5 space-y-4">
              <div>
                <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
                  {gettext("Transaction details")}
                </p>
                <p class="text-sm text-base-content/60">
                  {gettext("Register a movement for this fixed income.")}
                </p>
              </div>

              <div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:description]}
                  type="text"
                  label={gettext("Description")}
                  required
                />

                <.input
                  field={@form[:type]}
                  type="select"
                  label={gettext("Type")}
                  options={[{gettext("Deposit"), :deposit}, {gettext("Withdraw"), :withdraw}]}
                />
              </div>

              <.input
                field={@form[:value]}
                type="number"
                label={"Valor " <>
                  if @form[:type].value == :withdraw do
                    "(Máx. #{CurrencyUtils.format_money(@fixed_income.current_balance)})"
                  else
                    ""
                  end}
                required
                autocomplete="off"
                class="input input-bordered input-primary w-full"
              />
            </div>

            <div class="flex justify-end">
              <.button
                variant="primary"
                class="w-full sm:w-auto"
                phx-disable-with={gettext("Saving...")}
              >
                {gettext("Save")}
              </.button>
            </div>
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
