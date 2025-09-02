defmodule PersonalFinanceWeb.LedgersLive.LedgerForm do
  use PersonalFinanceWeb, :live_component
  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Ledger

  @impl true
  def update(assigns, socket) do
    current_scope = assigns.current_scope

    ledger =
      assigns.ledger || %Ledger{owner_id: current_scope.user.id}

    changeset =
      Finance.change_ledger(
        current_scope,
        ledger,
        %{}
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(form: to_form(changeset, as: :ledger))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"ledger" => ledger_params}, socket) do
    changeset =
      Finance.change_ledger(
        socket.assigns.current_scope,
        socket.assigns.ledger || %Ledger{owner_id: socket.assigns.current_scope.user.id},
        ledger_params
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate)
     )}
  end

  @impl true
  def handle_event("save", %{"ledger" => ledger_params}, socket) do
    save_ledger(socket, socket.assigns.action, ledger_params)
  end

  defp save_ledger(socket, :edit, ledger_params) do
    case Finance.update_ledger(
           socket.assigns.current_scope,
           socket.assigns.ledger,
           ledger_params
         ) do
      {:ok, ledger} ->
        send(socket.assigns.parent_pid, {:saved, ledger})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_ledger(socket, :new, ledger_params) do
    case Finance.create_ledger(
           socket.assigns.current_scope,
           ledger_params
         ) do
      {:ok, ledger} ->
        Finance.create_default_profiles(socket.assigns.current_scope, ledger)

        Finance.create_default_categories(socket.assigns.current_scope, ledger)

        send(socket.assigns.parent_pid, {:saved, ledger})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal
        show={@show}
        id="new-ledger-form"
        on_close={JS.push("close_modal")}
      >
        <:title>{if @action == :edit, do: "Editar Ledger", else: "Novo Ledger"}</:title>
        <.form
          for={@form}
          id="ledger-form"
          phx-submit="save"
          phx-change="validate"
          phx-target={@myself}
        >
          <.input field={@form[:name]} type="text" label="Nome" />
          <.input field={@form[:description]} type="text" label="Descrição" />

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
