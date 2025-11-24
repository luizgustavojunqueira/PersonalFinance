defmodule PersonalFinanceWeb.UserLive.Login do
  use PersonalFinanceWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} show_sidebar={false}>
      <div class="mx-auto max-w-sm space-y-4">
        <.header class="text-center">
          <p><%= gettext("Log in") %></p>
          <:subtitle>
            <%= if @current_scope do %>
              <%= gettext("You need to reauthenticate to perform sensitive actions on your account.") %>
            <% end %>
          </:subtitle>
        </.header>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
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
          />
          <.input
            :if={!@current_scope}
            field={f[:remember_me]}
            type="checkbox"
            label={gettext("Keep me logged in")}
          />
          <.button class="w-full" variant="primary">
            <%= gettext("Log in") %> <span aria-hidden="true">→</span>
          </.button>
        </.form>
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
