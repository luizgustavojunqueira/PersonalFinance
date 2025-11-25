defmodule PersonalFinanceWeb.UserLive.Login do
  use PersonalFinanceWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} show_sidebar={false} show_header={false}>
      <div class="mx-auto max-w-5xl px-4 py-12">
        <div class="flex justify-end gap-3 mb-6">
          <Layouts.locale_selector />
          <Layouts.theme_toggle />
        </div>

        <div class="grid gap-10 lg:grid-cols-[1.15fr_0.85fr] items-center">
          <div class="space-y-6 text-base-content">
            <div class="space-y-3">
              <p class="text-xs font-semibold uppercase tracking-[0.25em] text-primary/70">
                {gettext("Admin Area")}
              </p>
              <h1 class="text-3xl font-bold">
                {gettext("Access your finances securely.")}
              </h1>
              <p class="text-base text-base-content/70">
                {gettext("Use your admin credentials to enter the control panel.")}
              </p>
            </div>

            <div :if={@current_scope} class="inline-flex items-center gap-2 rounded-full border border-warning/40 bg-warning/10 px-4 py-2 text-sm font-medium text-warning">
              <.icon name="hero-lock-closed" class="h-4 w-4" />
              {gettext("Reauthentication required")}
            </div>

            <ul class="space-y-3 text-sm text-base-content/70">
              <li class="flex items-center gap-2">
                <.icon name="hero-server" class="h-4 w-4 text-primary" />
                <span>{gettext("Only you control the data. Everything stays on your server.")}</span>
              </li>
              <li class="flex items-center gap-2">
                <.icon name="hero-shield-check" class="h-4 w-4 text-success" />
                <span>{gettext("Encrypted sessions with scoped permissions.")}</span>
              </li>
              <li class="flex items-center gap-2">
                <.icon name="hero-arrows-right-left" class="h-4 w-4 text-secondary" />
                <span>{gettext("Switch profiles without leaving the dashboard.")}</span>
              </li>
            </ul>

            <p class="text-sm text-base-content/60">
              {gettext("Need help? Contact your instance administrator.")}
            </p>
          </div>

          <div class="rounded-3xl border border-base-200 bg-base-100/90 p-6 shadow-xl backdrop-blur lg:p-8">
            <div class="space-y-6">
              <div class="space-y-1">
                <p class="text-xs font-semibold uppercase tracking-wide text-primary/70">
                  {gettext("Log in")}
                </p>
                <p class="text-sm text-base-content/70">
                  <%= if @current_scope do %>
                    {gettext("You need to reauthenticate to perform sensitive actions on your account.")}
                  <% else %>
                    {gettext("Use your credentials to access the dashboard.")}
                  <% end %>
                </p>
              </div>

              <.form
                :let={f}
                for={@form}
                id="login_form_password"
                action={~p"/users/log-in"}
                phx-submit="submit_password"
                phx-trigger-action={@trigger_submit}
                class="space-y-4"
              >
                <.input
                  readonly={!!@current_scope}
                  field={f[:email]}
                  type="email"
                  label={gettext("Email")}
                  autocomplete="username"
                  required
                />
                <.input
                  field={@form[:password]}
                  type="password"
                  label={gettext("Password")}
                  autocomplete="current-password"
                  required
                />
                <.input
                  :if={!@current_scope}
                  field={f[:remember_me]}
                  type="checkbox"
                  label={gettext("Keep me logged in")}
                />
                <.button class="w-full" variant="primary">
                  <%= gettext("Log in") %>
                </.button>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
