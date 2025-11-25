defmodule PersonalFinanceWeb.AdminLive.UserFormComponent do
  use PersonalFinanceWeb, :live_component
  alias PersonalFinance.Accounts
  alias Phoenix.LiveView.JS

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal
        id={"user-form-modal-#{@id}"}
        show={@show}
        on_close={@on_close}
        backdrop_close={true}
        class="mt-2"
      >
        <:title>{modal_title(@action)}</:title>
        <:content>
          <p class="text-sm text-base-content/70">{modal_subtitle(@action)}</p>
        </:content>
        <.form
          for={@form}
          id="user-form"
          phx-change="validate"
          phx-submit="save"
          phx-target={@myself}
          class="space-y-6"
        >
          <div class="rounded-2xl border border-base-200 bg-base-100/80 px-5 py-4 text-sm text-base-content/70">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
              {gettext("Access level guidance")}
            </p>
            <p class="mt-2">
              {gettext(
                "Admins have full access to every ledger and can invite new teammates. Members manage their own ledgers and can be invited into others as collaborators."
              )}
            </p>
          </div>

          <div :if={@action == :new} class="grid gap-4 md:grid-cols-2">
            <.input field={@form[:name]} type="text" label={gettext("Full name")} autocomplete="name" required />
            <.input
              field={@form[:email]}
              type="email"
              label={gettext("Email")}
              autocomplete="username"
              required
            />
          </div>

          <div :if={@action == :edit} class="grid gap-4 md:grid-cols-2 rounded-2xl border border-base-200 bg-base-100/80 px-5 py-4">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
                {gettext("Full name")}
              </p>
              <p class="mt-1 text-base font-medium text-base-content">{@user.name}</p>
            </div>
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
                {gettext("Email")}
              </p>
              <p class="mt-1 text-base font-medium text-base-content">{@user.email}</p>
            </div>
          </div>

          <div :if={@action == :new} class="grid gap-4 md:grid-cols-2">
            <.input
              field={@form[:password]}
              type="password"
              label={password_label(@action)}
              autocomplete="new-password"
              required
            />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label={gettext("Confirm Password")}
              autocomplete="new-password"
              required
            />
          </div>

          <div class="grid gap-4">
            <div>
              <.input
                field={@form[:role]}
                type="select"
                label={gettext("Role")}
                options={role_options()}
                required
              />
              <p class="mt-1 text-xs text-base-content/60">
                {gettext("Choose admin for teammates who need full control.")}
              </p>
            </div>
          </div>

          <div class="flex justify-end gap-3 pt-4">
            <.button type="submit" class="btn-primary" phx-disable-with={gettext("Saving...")}>
              {gettext("Save")}
            </.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    changeset =
      case assigns.action do
        :new -> Accounts.change_user_email(user)
        :edit -> Accounts.change_user_role(user)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:show, fn -> true end)
     |> assign_new(:on_close, fn -> JS.push("close_form") end)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> changeset_for_action(socket.assigns.action, user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    role_params = Map.take(user_params, ["role"])

    case Accounts.admin_update_user_role(socket.assigns.user, role_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("User updated successfully"))
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user(socket, :new, user_params) do
    case Accounts.admin_create_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("User created successfully"))
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp modal_title(:new), do: gettext("Invite teammate")
  defp modal_title(:edit), do: gettext("Update permissions")

  defp modal_subtitle(:new) do
    gettext("Register a new teammate so they can access the system.")
  end

  defp modal_subtitle(:edit) do
    gettext("Existing user details are locked. Only the role can be updated from here.")
  end

  defp password_label(:new), do: gettext("Temporary password")
  defp password_label(:edit), do: gettext("Reset password (optional)")

  defp role_options do
    [
      {gettext("Member"), "user"},
      {gettext("Admin"), "admin"}
    ]
  end

  defp changeset_for_action(user, :new, params), do: Accounts.User.admin_changeset(user, params)
  defp changeset_for_action(user, :edit, params), do: Accounts.change_user_role(user, params)
end
