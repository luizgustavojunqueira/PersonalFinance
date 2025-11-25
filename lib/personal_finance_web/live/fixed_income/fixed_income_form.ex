defmodule PersonalFinanceWeb.FixedIncomeLive.FixedIncomeForm do
  alias PersonalFinance.Finance
  alias PersonalFinance.Investment
  alias PersonalFinance.Investment.{FixedIncome}

  use PersonalFinanceWeb, :live_component

  @impl true
  def update(assigns, socket) do
    ledger = assigns.ledger
    action = assigns.action || :new
    fixed_income = assigns.fixed_income || %FixedIncome{ledger_id: ledger.id}

    changeset =
      case action do
        :edit ->
          FixedIncome.update_changeset(fixed_income, %{})

        :new ->
          Investment.change_fixed_income(fixed_income, ledger, %{})
      end

    profiles = Finance.list_profiles(assigns.current_scope, ledger)

    socket =
      socket
      |> assign(assigns)
      |> assign(:profiles, Enum.map(profiles, fn profile -> {profile.name, profile.id} end))
      |> assign(form: to_form(changeset, as: :fixed_income))
      |> assign(action: action)

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
        <:title>
          {if @action == :edit do
            gettext("Edit Fixed Income")
          else
            gettext("New Fixed Income")
          end}
        </:title>
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
                label={gettext("Name")}
              />
            </div>

            <div>
              <.input
                field={@form[:institution]}
                type="text"
                label={gettext("Institution")}
              />
            </div>

            <div>
              <.input
                field={@form[:type]}
                type="select"
                label={gettext("Type")}
                options={[{"CDB", :cdb}]}
                disabled={@action == :edit}
              />
            </div>

            <div>
              <.input
                field={@form[:profile_id]}
                type="select"
                label={gettext("Profile")}
                options={@profiles}
                disabled={@action == :edit}
              />
            </div>

            <div>
              <.input
                field={@form[:remuneration_basis]}
                type="select"
                label={gettext("Remuneration basis")}
                options={[{"CDI", :cdi}]}
                disabled={@action == :edit}
              />
            </div>

            <div>
              <.input
                field={@form[:initial_investment]}
                type="number"
                label={gettext("Value (R$)")}
                autocomplete="off"
                disabled={@action == :edit}
              />
            </div>

            <div>
              <.input
                field={@form[:remuneration_rate]}
                type="number"
                label={gettext("Remuneration rate (%)")}
                step="0.01"
                min="0"
                disabled={@action == :edit}
              />
            </div>

            <div>
              <.input
                field={@form[:start_date_input]}
                type="date"
                label={gettext("Date")}
                disabled={@action == :edit}
              />
            </div>

            <div>
              <.input
                field={@form[:yield_frequency]}
                type="select"
                label={gettext("Yield frequency")}
                options={[
                  {gettext("Daily"), :daily},
                  {gettext("Monthly"), :monthly},
                  {gettext("Quarterly"), :quarterly},
                  {gettext("Semiannual"), :semiannual},
                  {gettext("Annual"), :annual},
                  {gettext("At maturity"), :at_maturity}
                ]}
                disabled={@action == :edit}
              />
            </div>

            <div>
              <.input
                field={@form[:end_date_input]}
                type="date"
                label={gettext("Maturity date")}
                disabled={@action == :edit}
              />
            </div>
          </div>

          <div class="flex justify-center gap-2 mt-4">
            <.button
              variant="custom"
              class="btn btn-primary w-full"
              phx-disable-with={gettext("Saving...")}
            >
              {gettext("Save")}
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
      case socket.assigns.action do
        :edit ->
          FixedIncome.update_changeset(socket.assigns.fixed_income, fixed_income_params)

        :new ->
          Investment.change_fixed_income(
            socket.assigns.fixed_income || %FixedIncome{ledger_id: socket.assigns.ledger.id},
            socket.assigns.ledger,
            fixed_income_params
          )
      end

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"fixed_income" => fixed_income_params}, socket) do
    case socket.assigns.action do
      :edit ->
        case Investment.update_fixed_income(socket.assigns.fixed_income, fixed_income_params) do
          {:ok, fixed_income} ->
            send(self(), {:saved, fixed_income})
            {:noreply, assign(socket, show: false)}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end

      :new ->
        case Investment.create_fixed_income(fixed_income_params, socket.assigns.ledger) do
          {:ok, fixed_income} ->
            send(self(), {:saved, fixed_income})
            {:noreply, assign(socket, show: false)}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end
end
