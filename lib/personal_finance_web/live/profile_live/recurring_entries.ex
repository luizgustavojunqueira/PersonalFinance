defmodule PersonalFinanceWeb.ProfileLive.RecurringEntries do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Finance.RecurringEntry
  alias PersonalFinance.Finance

  @impl true
  def render(assigns) do
    ~H"""
    <div class="rounded-lg  p-6  w-full shadow-lg bg-base-100/50">
      <h2 class="text-2xl font-semibold mb-4">Transações Recorrentes</h2>

      <.form
        for={@form}
        class="flex flex-col"
        phx-submit="save"
        phx-value-action={@form_action}
        phx-change="validate"
        phx-target={@myself}
      >
        <div class="flex justify-between items-center mb-4 gap-4">
          <.input field={@form[:description]} type="text" label="Descrição" required />
          <.input
            field={@form[:type]}
            type="select"
            label="Tipo"
            options={[{"Receita", :income}, {"Despesa", :expense}]}
            required
          />
          <.input
            field={@form[:frequency]}
            type="select"
            label="Frequência"
            options={[:monthly, :yearly]}
            required
          />
        </div>
        <div class="flex justify-between items-center mb-4 gap-4">
          <.input field={@form[:start_date]} type="date" label="Data de Início" required />
          <.input field={@form[:end_date]} type="date" label="Data de Término" />
        </div>
        <div class="flex justify-between items-center mb-4 gap-4">
          <.input field={@form[:amount]} type="number" label="Quantidade" step="0.01" required />
          <.input field={@form[:value]} type="number" label="Valor" step="0.01" required />
          <.input field={@form[:category_id]} type="select" label="Categoria" options={@categories} />
        </div>

        <div class="flex justify-end mt-4">
          <.button variant="primary" phx-disable-with="Salvando...">
            Salvar
          </.button>
        </div>
      </.form>
      <%= if @num_recurring_entries > 0 do %>
        <.table id="recurring_entries_table" rows={@streams.recurring_entries}>
          <:col :let={{_id, entry}} label="Descrição">{entry.description}</:col>
          <:col :let={{_id, entry}} label="Tipo">
            {if entry.type == :income do
              "Receita"
            else
              "Despesa"
            end}
          </:col>

          <:col :let={{_id, entry}} label="Categoria">{entry.category.name}</:col>
          <:col :let={{_id, entry}} label="Data de Início">
            {DateUtils.format_date(entry.start_date)}
          </:col>
          <:col :let={{_id, entry}} label="Data de Término">
            {DateUtils.format_date(entry.end_date)}
          </:col>
          <:col :let={{_id, entry}} label="Frequência">
            {if entry.frequency == :monthly do
              "Mensal"
            else
              "Anual"
            end}
          </:col>
          <:col :let={{_id, entry}} label="Status">
            {if entry.is_active do
              "Ativo"
            else
              "Inativo"
            end}
          </:col>

          <:action :let={{_id, entry}}>
            <.button
              variant="custom"
              class="btn btn-link p-0"
              phx-click="toggle_status"
              phx-value-id={entry.id}
              phx-target={@myself}
            >
              <.icon
                name="hero-check"
                class={
                  if entry.is_active,
                    do: "text-green-600 hover:text-green-800",
                    else: "text-gray-600 hover:text-gray-800"
                }
              />
            </.button>
          </:action>
          <:action :let={{_id, entry}}>
            <.button
              variant="custom"
              phx-click="edit"
              phx-value-id={entry.id}
              phx-target={@myself}
              class="btn btn-link p-0"
            >
              <.icon name="hero-pencil" class="text-blue-600 hover:text-blue-800" />
            </.button>
          </:action>
          <:action :let={{_id, entry}}>
            <.button
              variant="custom"
              phx-click="delete"
              phx-value-id={entry.id}
              phx-target={@myself}
              class="btn btn-link p-0"
            >
              <.icon name="hero-trash" class="text-red-600 hover:text-red-800" />
            </.button>
          </:action>
        </.table>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    recurring_entries =
      Finance.list_recurring_entries(
        assigns.current_scope,
        assigns.ledger.id,
        assigns.profile.id
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(
        categories:
          Enum.map(Finance.list_categories(assigns.current_scope, assigns.ledger), fn category ->
            {category.name, category.id}
          end),
        form_action: :create,
        form:
          to_form(
            Finance.change_recurring_entry(
              assigns.current_scope,
              %Finance.RecurringEntry{
                ledger_id: assigns.ledger.id,
                profile_id: assigns.profile.id
              },
              assigns.ledger
            )
          ),
        num_recurring_entries: Enum.count(recurring_entries)
      )
      |> stream(:recurring_entries, recurring_entries)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"recurring_entry" => params}, socket) do
    changeset =
      Finance.change_recurring_entry(
        socket.assigns.current_scope,
        %Finance.RecurringEntry{
          ledger_id: socket.assigns.ledger.id,
          profile_id: socket.assigns.profile.id
        },
        socket.assigns.ledger,
        params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("toggle_status", %{"id" => id}, socket) do
    recurring_entry =
      Finance.get_recurring_entry(socket.assigns.current_scope, socket.assigns.ledger.id, id)

    case Finance.toggle_recurring_entry_status(socket.assigns.current_scope, recurring_entry) do
      {:ok, updated_entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Status da transação recorrente atualizado com sucesso.")
         |> stream_insert(:recurring_entries, updated_entry)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Erro ao atualizar status da transação recorrente: #{changeset.errors[:base]}"
         )
         |> assign(form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    recurring_entry =
      Finance.get_recurring_entry(socket.assigns.current_scope, socket.assigns.ledger.id, id)

    changeset =
      Finance.change_recurring_entry(
        socket.assigns.current_scope,
        recurring_entry,
        socket.assigns.ledger
      )

    {:noreply,
     socket
     |> assign(form: to_form(changeset, action: :update))
     |> assign(
       form_action: :update,
       recurring_entry: recurring_entry
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    recurring_entry =
      Finance.get_recurring_entry(socket.assigns.current_scope, socket.assigns.ledger.id, id)

    case Finance.delete_recurring_entry(
           socket.assigns.current_scope,
           recurring_entry
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transação recorrente removida com sucesso.")
         |> assign(num_recurring_entries: socket.assigns.num_recurring_entries - 1)
         |> stream_delete(:recurring_entries, recurring_entry)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Erro ao remover transação recorrente: #{changeset.errors[:base]}")
         |> assign(form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("save", %{"recurring_entry" => params, "action" => action}, socket) do
    save(String.to_existing_atom(action), params, socket)
  end

  defp save(:create, params, socket) do
    case Finance.create_recurring_entry(
           socket.assigns.current_scope,
           Map.put(params, "profile_id", socket.assigns.profile.id),
           socket.assigns.ledger
         ) do
      {:ok, recurring_entry} ->
        {:noreply,
         socket
         |> assign(
           form:
             to_form(
               Finance.change_recurring_entry(
                 socket.assigns.current_scope,
                 %Finance.RecurringEntry{
                   ledger_id: socket.assigns.ledger.id,
                   profile_id: socket.assigns.profile.id
                 },
                 socket.assigns.ledger
               )
             ),
           num_recurring_entries: socket.assigns.num_recurring_entries + 1
         )
         |> put_flash(:info, "Transação recorrente salva com sucesso.")
         |> stream_insert(:recurring_entries, recurring_entry)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save(:update, params, socket) do
    recurring_entry =
      Finance.get_recurring_entry(
        socket.assigns.current_scope,
        socket.assigns.ledger.id,
        socket.assigns.recurring_entry.id
      )

    case Finance.update_recurring_entry(
           socket.assigns.current_scope,
           recurring_entry,
           params
         ) do
      {:ok, updated_entry} ->
        {:noreply,
         socket
         |> assign(
           form:
             to_form(
               Finance.change_recurring_entry(
                 socket.assigns.current_scope,
                 %RecurringEntry{
                   ledger_id: socket.assigns.ledger.id,
                   profile_id: socket.assigns.profile.id
                 },
                 socket.assigns.ledger
               )
             )
         )
         |> put_flash(:info, "Transação recorrente atualizada com sucesso.")
         |> stream_insert(:recurring_entries, updated_entry)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
