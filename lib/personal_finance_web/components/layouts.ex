defmodule PersonalFinanceWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use PersonalFinanceWeb, :html

  embed_templates "layouts/*"

  def app(assigns) do
    ~H"""
    <div class="flex flex-col h-screen max-h-screen overflow-hidden">
      <.page_header current_scope={@current_scope} class="flex-shrink-0" />
      <%= if @show_sidebar do %>
        <.navigation_sidebar ledger={@ledger} current_scope={@current_scope} />
      <% end %>
      <div class={"flex flex-row flex-1 max-h-screen max-w-screen #{if @show_sidebar, do: "md:pl-14"}"}>
        <main class="flex-1 overflow-y-auto px-4 pb-4 ">
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
      class="fixed bottom-0 left-0 right-0 z-50 flex flex-col items-center gap-2 p-4"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

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
    <div class="card relative flex flex-row items-center  rounded-full light">
      <div class="absolute w-[33%] h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-[33%] [[data-theme=dark]_&]:left-[66%] transition-[left]" />

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
      class="fixed top-16 z-50 h-screen bg-dark-green dark:bg-emerald-900/100 text-white transition-all duration-300 overflow-x-hidden
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
              navigate={~p"/ledgers/#{@ledger.id}/profiles"}
              class="flex items-center gap-2 sidebar-link"
            >
              <.icon name="hero-users" class="size-6" />
              <span class="sidebar-text hidden md:inline">Perfis</span>
            </.link>
          </li>
          <li class=" mb-4 ">
            <.link
              navigate={~p"/ledgers/#{@ledger.id}/categories"}
              class="flex items-center gap-2 sidebar-link"
            >
              <.icon name="hero-tag" class="size-6" />
              <span class="sidebar-text hidden md:inline">Categorias</span>
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
        <% end %>
      </ul>
    </div>
    """
  end

  def page_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between w-full:pl-2 pr-4 py-2 bg-dark-green dark:bg-emerald-900/90 text-white dark:text-offwhite min-h-[64px]">
      <button
        id="toggle-sidebar"
        phx-hook="ToggleSidebar"
        class="flex items-center justify-center w-10 h-10 bg-dark-green text-white rounded"
      >
        <.icon name="hero-bars-3" class="open-icon size-6" />
        <.icon name="hero-x-mark" class="close-icon size-6 hidden" />
      </button>
      <ul class="w-full flex flex-row text-xs md:text-lg items-center gap-2 px-2 sm:gap-4 sm:px-6 lg:px-8 py-1 sm:py-2 lg:py-3 justify-end bg-dark-green dark:bg-emerald-900/90 text-white dark:text-offwhite min-h-[64px]">
        <li>
          <Layouts.theme_toggle />
        </li>
        <%= if @current_scope do %>
          <li class="medium  rounded-full py-1 px-2">
            {@current_scope.user.email}
          </li>
          <li class="light hover-medium rounded-full py-1 px-2">
            <.link href={~p"/users/settings"}>Settings</.link>
          </li>
          <li class="light hover-medium rounded-full py-1 px-2">
            <.link href={~p"/users/log-out"} method="delete">Log out</.link>
          </li>
        <% else %>
          <li class="light hover-medium rounded-full py-1 px-2">
            <.link href={~p"/users/register"}>Register</.link>
          </li>
          <li class="light hover-medium rounded-full py-1 px-2">
            <.link href={~p"/users/log-in"}>Log in</.link>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
