defmodule PersonalFinanceWeb.UserLive.Setup do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Accounts.User
  alias PersonalFinance.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={nil} show_sidebar={false}>
      <div class="mx-auto max-w-sm">
        <.header class="text-center">
          <%= gettext("Initial Setup") %>
          <:subtitle>
            <%= gettext("Create the first admin account for your Personal Finance system.") %>
          </:subtitle>
        </.header>

        <.form for={@form} id="setup_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:name]}
            type="text"
            label={gettext("Admin Name")}
            autocomplete="name"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={@form[:email]}
            type="email"
            label={gettext("Admin Email")}
            autocomplete="username"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label={gettext("Password")}
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

          <.button variant="primary" phx-disable-with={gettext("Creating admin...")} class="w-full">
            <%= gettext("Create Admin Account") %>
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_param, _session, socket) do
    if not Accounts.first_user_setup_required?() do
      {:ok, push_navigate(socket, to: ~p"/users/log-in")}
    else
      changeset = Accounts.change_user_email(%User{})
      {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
    end
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.create_first_admin_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Admin account created successfully! You can now log in."))
         |> redirect(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = %User{} |> User.admin_changeset(user_params) |> Map.put(:action, :validate)
    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
