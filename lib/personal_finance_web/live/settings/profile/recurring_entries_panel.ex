defmodule PersonalFinanceWeb.SettingsLive.RecurringEntriesPanel do
  use PersonalFinanceWeb, :live_component

  alias Phoenix.LiveView.JS
  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.RecurringEntry
  alias PersonalFinance.Utils.DateUtils
  alias PersonalFinance.Utils.ParseUtils

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:open_modal, nil)
     |> assign(:form_action, :create)
     |> assign(:recurring_entry, nil)}
  end

  @impl true
  def update(assigns, socket) do
    recurring_entries =
      Finance.list_recurring_entries(
        assigns.current_scope,
        assigns.ledger.id,
        assigns.profile.id
      )

    categories = categories_options(assigns)

    socket =
      socket
      |> assign(assigns)
      |> assign(:categories, categories)
      |> assign(:num_recurring_entries, Enum.count(recurring_entries))
      |> assign_new(:form, fn -> to_form(new_changeset(assigns)) end)
      |> assign_new(:form_action, fn -> :create end)
      |> assign_new(:recurring_entry, fn -> nil end)
      |> assign_new(:open_modal, fn -> nil end)
      |> stream(:recurring_entries, recurring_entries, reset: true)

    {:ok, socket}
  end

  @impl true
  def handle_event("open_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:open_modal, :recurring_entry)
     |> assign(:form_action, :create)
     |> assign(:recurring_entry, nil)
     |> assign(:form, to_form(new_changeset(socket.assigns)))}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:open_modal, nil)
     |> assign(:form_action, :create)
     |> assign(:recurring_entry, nil)
     |> assign(:form, to_form(new_changeset(socket.assigns)))}
  end

  @impl true
  def handle_event("validate", %{"recurring_entry" => params}, socket) do
    changeset =
      Finance.change_recurring_entry(
        socket.assigns.current_scope,
        %RecurringEntry{
          ledger_id: socket.assigns.ledger.id,
          profile_id: socket.assigns.profile.id
        },
        socket.assigns.ledger,
        params
      )

    formatted_value = ParseUtils.format_float_for_input(changeset.data.value)
    formatted_amount = ParseUtils.format_float_for_input(changeset.data.amount)

    changeset =
      changeset
      |> Ecto.Changeset.put_change(:value, formatted_value)
      |> Ecto.Changeset.put_change(:amount, formatted_amount)

    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("toggle_status", %{"id" => id}, socket) do
    recurring_entry =
      Finance.get_recurring_entry(socket.assigns.current_scope, socket.assigns.ledger.id, id)

    case Finance.toggle_recurring_entry_status(socket.assigns.current_scope, recurring_entry) do
      {:ok, updated_entry} ->
        send_flash(socket, :info, gettext("Recurring transaction status successfully updated."))

        {:noreply,
         socket
         |> stream_insert(:recurring_entries, updated_entry)}

      {:error, _changeset} ->
        send_flash(socket, :error, gettext("Error updating recurring transaction status."))
        {:noreply, socket}
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

    formatted_value = ParseUtils.format_float_for_input(changeset.data.value)
    formatted_amount = ParseUtils.format_float_for_input(changeset.data.amount)

    start_date_input =
      case recurring_entry.start_date do
        %DateTime{} = dt -> DateTime.to_date(dt)
        %NaiveDateTime{} = dt -> NaiveDateTime.to_date(dt)
        %Date{} = date -> date
        _ -> nil
      end

    end_date_input =
      case recurring_entry.end_date do
        %DateTime{} = dt -> DateTime.to_date(dt)
        %NaiveDateTime{} = dt -> NaiveDateTime.to_date(dt)
        %Date{} = date -> date
        _ -> nil
      end

    changeset =
      changeset
      |> Ecto.Changeset.put_change(:value, formatted_value)
      |> Ecto.Changeset.put_change(:amount, formatted_amount)
      |> Ecto.Changeset.put_change(:start_date_input, start_date_input)
      |> Ecto.Changeset.put_change(:end_date_input, end_date_input)

    {:noreply,
     socket
     |> assign(:open_modal, :recurring_entry)
     |> assign(:form_action, :update)
     |> assign(:recurring_entry, recurring_entry)
     |> assign(:form, to_form(changeset, action: :update))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    recurring_entry =
      Finance.get_recurring_entry(socket.assigns.current_scope, socket.assigns.ledger.id, id)

    case Finance.delete_recurring_entry(socket.assigns.current_scope, recurring_entry) do
      {:ok, _deleted} ->
        send_flash(socket, :info, gettext("Recurring transaction successfully deleted."))

        {:noreply,
         socket
         |> assign(:num_recurring_entries, max(socket.assigns.num_recurring_entries - 1, 0))
         |> stream_delete(:recurring_entries, recurring_entry)}

      {:error, changeset} ->
        send_flash(socket, :error, gettext("Error deleting recurring transaction."))
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("save", %{"recurring_entry" => params, "action" => action}, socket) do
    case String.to_existing_atom(action) do
      :create -> save_new(params, socket)
      :update -> save_existing(params, socket)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="space-y-4">
        <div class="flex items-center mt-2">
          <.button variant="primary" size="sm" phx-click="open_modal" phx-target={@myself}>
            <.icon name="hero-plus" class="w-4 h-4 mr-1" />
            {gettext("New recurring transaction")}
          </.button>
        </div>

        <%= if @num_recurring_entries > 0 do %>
          <.table id={"recurring-entries-#{@profile.id}"} rows={@streams.recurring_entries}>
          <:col :let={{_id, entry}} label={gettext("Description")}>
            <.text_ellipsis text={entry.description} max_width="max-w-[16rem]" />
          </:col>
          <:col :let={{_id, entry}} label={gettext("Type")}>
            {if entry.type == :income, do: gettext("Income"), else: gettext("Expense")}
          </:col>
          <:col :let={{_id, entry}} label={gettext("Category")}>
            <.text_ellipsis text={entry.category && entry.category.name} max_width="max-w-[12rem]" />
          </:col>
          <:col :let={{_id, entry}} label={gettext("Frequency")}>
            {if entry.frequency == :monthly, do: gettext("Monthly"), else: gettext("Yearly")}
          </:col>
          <:col :let={{_id, entry}} label={gettext("Period")}>
            <div class="flex flex-col text-xs">
              <span>{gettext("Start")}: {DateUtils.format_date(entry.start_date)}</span>
              <span>{gettext("End")}: {DateUtils.format_date(entry.end_date)}</span>
            </div>
          </:col>
          <:col :let={{_id, entry}} label={gettext("Status")}>
            <span class={entry.is_active && "text-success" || "text-base-content/60"}>
              {if entry.is_active, do: gettext("Active"), else: gettext("Inactive")}
            </span>
          </:col>
          <:action :let={{_id, entry}}>
            <.button
              variant="custom"
              size="sm"
              class="btn-circle btn-ghost"
              phx-click="toggle_status"
              phx-value-id={entry.id}
              phx-target={@myself}
              title={gettext("Activate/Deactivate")}
            >
              <.icon name="hero-check" class={entry.is_active && "text-success" || "text-base-content/60"} />
            </.button>
          </:action>
          <:action :let={{_id, entry}}>
            <.button
              variant="custom"
              size="sm"
              class="btn-circle btn-ghost"
              phx-click="edit"
              phx-value-id={entry.id}
              phx-target={@myself}
              title={gettext("Edit")}
            >
              <.icon name="hero-pencil" class="text-primary" />
            </.button>
          </:action>
          <:action :let={{_id, entry}}>
            <.button
              variant="custom"
              size="sm"
              class="btn-circle btn-ghost"
              phx-click="delete"
              phx-value-id={entry.id}
              phx-target={@myself}
              title={gettext("Delete")}
            >
              <.icon name="hero-trash" class="text-error" />
            </.button>
          </:action>
          </.table>
        <% else %>
          <div class="rounded-xl border border-dashed border-base-300 bg-base-100/80 p-6 text-sm text-base-content/70">
            {gettext("No recurring transactions registered for this profile.")}
          </div>
        <% end %>
      </div>

      <.modal
        id={"recurring-entry-modal-#{@profile.id}"}
        show={@open_modal == :recurring_entry}
        on_close={JS.push("close_modal", target: @myself)}
      >
        <:title>
          <%= if @form_action == :create do %>
            {gettext("New recurring transaction")}
          <% else %>
            {gettext("Edit recurring transaction")}
          <% end %>
        </:title>

        <.form
          for={@form}
          class="flex flex-col gap-4"
          phx-submit="save"
          phx-change="validate"
          phx-value-action={@form_action}
          phx-target={@myself}
        >
          <div class="grid gap-4 md:grid-cols-2">
            <.input field={@form[:description]} type="text" label={gettext("Description")} />
            <.input
              field={@form[:type]}
              type="select"
              label={gettext("Type")}
              options={[{gettext("Income"), :income}, {gettext("Expense"), :expense}]}
            />
            <.input
              field={@form[:frequency]}
              type="select"
              label={gettext("Frequency")}
              options={[{gettext("Monthly"), :monthly}, {gettext("Yearly"), :yearly}]}
            />
            <.input field={@form[:category_id]} type="select" label={gettext("Category")} options={@categories} />
            <.input field={@form[:start_date_input]} type="date" label={gettext("Start date")} />
            <.input field={@form[:end_date_input]} type="date" label={gettext("End date")} />
            <.input field={@form[:amount]} type="number" label={gettext("Amount")} step="0.01" />
            <.input field={@form[:value]} type="number" label={gettext("Value")} step="0.01" />
          </div>

          <div class="flex justify-end gap-2">
            <.button type="button" phx-click="close_modal" phx-target={@myself}>
              {gettext("Cancel")}
            </.button>
            <.button variant="primary" phx-disable-with={gettext("Saving...")}>
              {gettext("Save")}
            </.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  defp save_new(params, socket) do
    case Finance.create_recurring_entry(
           socket.assigns.current_scope,
           Map.put(params, "profile_id", socket.assigns.profile.id),
           socket.assigns.ledger
         ) do
      {:ok, recurring_entry} ->
        send_flash(socket, :info, gettext("Recurring transaction successfully created."))

        {:noreply,
         socket
         |> assign(:open_modal, nil)
         |> assign(:form, to_form(new_changeset(socket.assigns)))
         |> assign(:num_recurring_entries, socket.assigns.num_recurring_entries + 1)
         |> stream_insert(:recurring_entries, recurring_entry)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_existing(params, socket) do
    recurring_entry =
      Finance.get_recurring_entry(
        socket.assigns.current_scope,
        socket.assigns.ledger.id,
        socket.assigns.recurring_entry.id
      )

    case Finance.update_recurring_entry(socket.assigns.current_scope, recurring_entry, params) do
      {:ok, updated_entry} ->
        send_flash(socket, :info, gettext("Recurring transaction successfully updated."))

        {:noreply,
         socket
         |> assign(:open_modal, nil)
         |> assign(:recurring_entry, nil)
         |> assign(:form, to_form(new_changeset(socket.assigns)))
         |> stream_insert(:recurring_entries, updated_entry)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp new_changeset(assigns) do
    Finance.change_recurring_entry(
      assigns.current_scope,
      %RecurringEntry{ledger_id: assigns.ledger.id, profile_id: assigns.profile.id},
      assigns.ledger
    )
  end

  defp categories_options(assigns) do
    assigns.current_scope
    |> Finance.list_categories(assigns.ledger)
    |> Enum.map(&{&1.name, &1.id})
  end

  defp send_flash(socket, type, message) do
    send(socket.assigns.parent_pid, {:put_flash, type, message})
  end
end
