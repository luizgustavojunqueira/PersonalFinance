defmodule PersonalFinanceWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  alias PersonalFinance.Accounts.User
  use PersonalFinanceWeb, :html

  embed_templates "layouts/*"

  def app(assigns) do
    ~H"""
    <div class="flex flex-col h-screen max-h-screen overflow-hidden">
      <.page_header current_scope={@current_scope} class="flex-shrink-0" />

      <div class="flex flex-row flex-1 min-h-0">
        <%= if @show_sidebar do %>
          <.navigation_sidebar ledger={@ledger} current_scope={@current_scope} />
        <% end %>

        <main class={"flex-1 overflow-y-auto px-4 pb-4 mt-15 #{if @show_sidebar, do: "md:ml-14"}"}>
          {render_slot(@inner_block)}
        </main>
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="fixed bottom-0 right-0 z-50 flex flex-col items-end gap-2 p-4"
    >
      <.flash kind={:info} flash={@flash} auto_close={2000} />
      <.flash kind={:error} flash={@flash} auto_close={5000} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-[33%] h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-[33%] [[data-theme=dark]_&]:left-[66%] transition-[left] duration-300" />

      <button phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})} class="flex p-2">
        <.icon name="hero-computer-desktop-micro" class="size-6 opacity-75 hover:opacity-100" />
      </button>

      <button phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})} class="flex p-2">
        <.icon name="hero-sun-micro" class="size-6 opacity-75 hover:opacity-100" />
      </button>

      <button phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})} class="flex p-2">
        <.icon name="hero-moon-micro" class="size-6 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  def navigation_sidebar(assigns) do
    ~H"""
    <div
      id="sidebar"
      class="fixed top-16 left-0 z-40 h-[calc(100vh-4rem)] bg-base-100 transition-all duration-300 overflow-x-hidden
         hidden md:block w-14
         [&.expanded]:block [&.expanded]:w-64"
    >
      <ul class="mt-4 space-y-4 px-2">
        <li>
          <.link navigate={~p"/ledgers"} class="flex items-center gap-2 sidebar-link">
            <.icon name="hero-book-open" class="size-6" />

            <span class="sidebar-text hidden group-hover:inline">Ledgers</span>
          </.link>
        </li>
        <%= if @ledger do %>
          <li class=" mb-4 ">
            <.link
              navigate={~p"/ledgers/#{@ledger.id}/home"}
              class="flex items-center gap-2 sidebar-link"
            >
              <.icon name="hero-home" class="size-6" />
              <span class="sidebar-text md:inline hidden">Home</span>
            </.link>
          </li>
          <li class=" mb-4 ">
            <.link
              navigate={~p"/ledgers/#{@ledger.id}/transactions"}
              class="flex items-center gap-2 sidebar-link"
            >
              <.icon name="hero-clipboard-document-list" class="size-6" />
              <span class="sidebar-text hidden md:inline">Transações</span>
            </.link>
          </li>
          <li class=" mb-4 ">
            <.link
              navigate={~p"/ledgers/#{@ledger.id}/fixed_income"}
              class="flex items-center gap-2 sidebar-link"
            >
              <.icon name="hero-currency-dollar" class="size-6" />
              <span class="sidebar-text hidden md:inline">Renda Fixa</span>
            </.link>
          </li>
          <%= if @ledger.owner_id == @current_scope.user.id do %>
            <li class=" mb-4 ">
              <.link
                navigate={~p"/ledgers/#{@ledger.id}/settings"}
                class="flex items-center gap-2 sidebar-link"
              >
                <.icon name="hero-cog-6-tooth" class="size-6" />
                <span class="sidebar-text hidden md:inline">Configurações</span>
              </.link>
            </li>
          <% end %>
        <% else %>
          <%= if User.admin?(@current_scope.user)  do %>
            <li class=" mb-4 ">
              <.link navigate={~p"/admin/users"} class="flex items-center gap-2 sidebar-link">
                <.icon name="hero-users" class="size-6" />
                <span class="sidebar-text hidden md:inline">Users</span>
              </.link>
            </li>
          <% end %>
        <% end %>
      </ul>
    </div>
    """
  end

  def page_header(assigns) do
    ~H"""
    <div class="navbar bg-base-100 shadow-sm fixed top-0 left-0 right-0 z-50 h-16">
      <div class="navbar-start">
        <button id="toggle-sidebar" phx-hook="ToggleSidebar" class="btn btn-ghost btn-square">
          <.icon name="hero-bars-3" class="open-icon size-6" />
          <.icon name="hero-x-mark" class="close-icon size-6 hidden" />
        </button>
      </div>
      <div class="navbar-end gap-4">
        <Layouts.theme_toggle />
        <div class="dropdown dropdown-end">
          <div tabindex="0" role="button" class="btn btn-ghost lg:hidden">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 6h16M4 12h8m-8 6h16"
              />
            </svg>
          </div>
          <ul
            tabindex="0"
            class="dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow-sm"
          >
            <%= if @current_scope do %>
              <li class="p-2">{@current_scope.user.email}</li>
              <li>
                <.link href={~p"/users/settings"}>Settings</.link>
              </li>
              <li>
                <.link href={~p"/users/log-out"} method="delete">Log out</.link>
              </li>
            <% else %>
              <li>
                <.link href={~p"/users/log-in"}>Log in</.link>
              </li>
            <% end %>
          </ul>
        </div>
        <div class="hidden lg:flex items-center gap-4">
          <%= if @current_scope do %>
            {@current_scope.user.email}
            <.link href={~p"/users/settings"}>Settings</.link>
            <.link href={~p"/users/log-out"} method="delete">Log out</.link>
          <% else %>
            <.link href={~p"/users/log-in"}>Log in</.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
