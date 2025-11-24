defmodule PersonalFinanceWeb.SettingsLive.AccessPanel do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinance.Finance

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:parent_pid, fn -> self() end)
      |> assign_new(:selected_user_id, fn -> nil end)
      |> assign_new(:available_users, fn -> [] end)
      |> assign_new(:ledger_users, fn -> [] end)
      |> assign_new(:invite_form, fn -> build_invite_form() end)
      |> assign_new(:loaded?, fn -> false end)

    needs_refresh? = Map.get(assigns, :refresh, false) || !socket.assigns.loaded?

    socket = if needs_refresh?, do: refresh_data(socket), else: socket

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="rounded-xl border border-base-300 bg-base-100/70 p-4">
        <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
          {gettext("Access")}
        </p>
          <h2 class="text-xl font-semibold text-base-content">{gettext("Manage ledger collaborators")}</h2>
      </div>

      <div class="grid gap-6 grid-cols-1 lg:grid-cols-[minmax(0,40%)_minmax(0,60%)]">
        <section class="space-y-4 rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm">
          <div>
            <h3 class="text-xl font-semibold text-base-content">{gettext("Invite")}</h3>
            <p class="text-sm text-base-content/60">
              {gettext("Choose a user to collaborate on this ledger.")}
            </p>
          </div>

          <.form
            for={@invite_form}
            id={"#{@id}-invite-form"}
            phx-submit="add_user"
            phx-change="validate_invite"
            phx-target={@myself}
            class="flex flex-col gap-3"
          >
            <.input
              field={@invite_form[:user_id]}
              type="select"
              label={gettext("User")}
              options={@available_users}
              prompt={gettext("Select a user")}
            />

            <.button
              variant="primary"
              phx-disable-with={gettext("Adding...")}
              disabled={@selected_user_id in [nil, ""]}
            >
              <.icon name="hero-user-plus" class="w-4 h-4" /> {gettext("Add collaborator")}
            </.button>
          </.form>

          <%= if @available_users == [] do %>
            <div class="rounded-xl border border-dashed border-base-300 bg-base-100/60 p-4 text-xs text-base-content/60">
              {gettext("All eligible users are already part of this ledger.")}
            </div>
          <% end %>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm">
          <div class="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
            <div>
              <h3 class="text-xl font-semibold text-base-content">{gettext("Collaborators")}</h3>
              <p class="text-sm text-base-content/60">{gettext("Manage who has access to this ledger.")}</p>
            </div>
            <span class="text-sm text-base-content/60">{Gettext.ngettext(PersonalFinanceWeb.Gettext, "%{count} in total", "%{count} in total", length(@ledger_users), count: length(@ledger_users))}</span>
          </div>

          <%= if @ledger_users == [] do %>
            <div class="mt-4 rounded-xl border border-dashed border-base-300 bg-base-100/70 p-6 text-sm text-base-content/70">
              {gettext("No collaborators added.")}
            </div>
          <% else %>
            <div class="mt-4">
              <.table
                id={"#{@id}-ledger-users"}
                rows={@ledger_users}
                col_widths={["35%", "25%", "10%"]}
              >
                <:col :let={user} label={gettext("Collaborator")}>
                  <div class="flex flex-col">
                    <span class="font-semibold">{user.name}</span>
                    <span class="text-sm text-base-content/60">{user.email}</span>
                  </div>
                </:col>
                <:col :let={user} label={gettext("Type")}>
                  <span class="uppercase text-xs tracking-wide text-base-content/70">
                    <%= if @ledger.owner_id == user.id do %>
                      {gettext("Owner")}
                    <% else %>
                      {gettext("Collaborator")}
                    <% end %>
                  </span>
                </:col>
                <:action :let={user}>
                  <%= if @ledger.owner_id != user.id && @ledger.owner_id == @current_scope.user.id do %>
                    <.link
                      class="btn btn-ghost btn-xs text-error"
                      phx-click="remove_user"
                      phx-value-id={user.id}
                      phx-target={@myself}
                    >
                      <.icon name="hero-trash" class="w-5 h-5" />
                    </.link>
                  <% end %>
                </:action>
              </.table>
            </div>
          <% end %>
        </section>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate_invite", %{"ledger_invite" => %{"user_id" => id}}, socket) do
    {:noreply, assign(socket, selected_user_id: id)}
  end

  def handle_event("add_user", %{"ledger_invite" => %{"user_id" => user_id}}, socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope

    case Finance.add_ledger_user(current_scope, ledger, user_id) do
      {:ok, user} ->
        notify_parent(
          socket,
          {:put_flash, :info, "#{gettext("Collaborator")} #{user.email} #{gettext("successfully added.")}"}
        )

        {:noreply, refresh_data(socket)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, invite_form: to_form(changeset))}

      {:error, message} ->
        notify_parent(socket, {:put_flash, :error, message})
        {:noreply, socket}
    end
  end

  def handle_event("remove_user", %{"id" => user_id}, socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope

    case Finance.remove_ledger_user(current_scope, ledger, user_id) do
      {:ok, _} ->
        notify_parent(socket, {:put_flash, :info, gettext("Collaborator successfully removed.")})
        {:noreply, refresh_data(socket)}

      {:error, reason} ->
        notify_parent(socket, {:put_flash, :error, reason})
        {:noreply, socket}
    end
  end

  defp refresh_data(socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope

    available_users =
      Finance.list_available_ledger_users(current_scope, ledger)
      |> Enum.map(&{&1.name, &1.id})

    ledger_users = Finance.list_ledger_users(current_scope, ledger)

    socket
    |> assign(:available_users, available_users)
    |> assign(:ledger_users, ledger_users)
    |> assign(:invite_form, build_invite_form())
    |> assign(:selected_user_id, nil)
    |> assign(:loaded?, true)
  end

  defp build_invite_form do
    to_form(%{"user_id" => nil}, as: :ledger_invite)
  end

  defp notify_parent(socket, message) do
    send(socket.assigns.parent_pid, message)
  end
end
