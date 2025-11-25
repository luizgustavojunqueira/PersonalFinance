defmodule PersonalFinanceWeb.UserLive.Setup do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Accounts.User
  alias PersonalFinance.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={nil} show_sidebar={false} show_header={false}>
      <div class="mx-auto max-w-5xl px-4 py-12">
        <div class="flex justify-end gap-3 mb-6">
          <Layouts.locale_selector />
          <Layouts.theme_toggle />
        </div>

        <div class="grid gap-10 lg:grid-cols-[1.1fr_0.9fr] items-center">
          <div class="space-y-6 text-base-content">
            <div class="space-y-3">
              <p class="text-xs font-semibold uppercase tracking-[0.25em] text-primary/70">
                {gettext("Instance Setup")}
              </p>
              <h1 class="text-3xl font-bold">
                {gettext("Prepare your admin account.")}
              </h1>
              <p class="text-base text-base-content/70">
                {gettext("A few quick steps before tracking your finances.")}
              </p>
            </div>

            <ul class="space-y-3 text-sm text-base-content/70">
              <li class="flex items-center gap-2">
                <.icon name="hero-identification" class="h-4 w-4 text-primary" />
                <span>
                  {gettext("Define who will manage this instance. You can add more admins later.")}
                </span>
              </li>
              <li class="flex items-center gap-2">
                <.icon name="hero-key" class="h-4 w-4 text-secondary" />
                <span>{gettext("These credentials unlock every ledger and profile.")}</span>
              </li>
              <li class="flex items-center gap-2">
                <.icon name="hero-lock-closed" class="h-4 w-4 text-success" />
                <span>{gettext("Store them in a secure password manager.")}</span>
              </li>
            </ul>
          </div>

          <div class="rounded-3xl border border-base-200 bg-base-100/90 p-6 shadow-xl backdrop-blur lg:p-8">
            <div class="space-y-6">
              <div class="space-y-1">
                <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
                  {gettext("Initial Setup")}
                </p>
                <p class="text-sm text-base-content/70">
                  {gettext("Create the first admin account for your Personal Finance system.")}
                </p>
              </div>

              <.form
                for={@form}
                id="setup_form"
                phx-submit="save"
                phx-change="validate"
                class="space-y-4"
              >
                <.input
                  field={@form[:name]}
                  type="text"
                  label={gettext("Admin name")}
                  autocomplete="name"
                  required
                  phx-mounted={JS.focus()}
                />
                <.input
                  field={@form[:email]}
                  type="email"
                  label={gettext("Admin email")}
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

                <.button
                  variant="primary"
                  phx-disable-with={gettext("Creating admin...")}
                  class="w-full"
                >
                  {gettext("Create Admin Account")}
                </.button>
              </.form>
            </div>
          </div>
        </div>
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
