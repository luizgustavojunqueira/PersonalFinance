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
    <div class="flex flex-col h-screen">
      <.page_header current_scope={@current_scope} />
      <main class="flex flex-row h-full w-full">
        <%= if @show_sidebar do %>
          <.navigation_sidebar budget_id={@budget_id} />
        <% end %>
        <div class="h-full w-full px-4 py-2 ">
          {render_slot(@inner_block)}
        </div>
        <.flash_group flash={@flash} />
      </main>
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
    <div id="sidebar" class="medium overflow-hidden transition-all duration-300 collapsed">
      <button
        id="toggle-sidebar"
        phx-hook="ToggleSidebar"
        class="toggle-btn flex items-center p-2 w-full"
      >
        <.icon name="hero-bars-3" class="open-icon size-6 " />
        <.icon name="hero-x-mark" class="close-icon size-6 hidden " />
      </button>
      <ul class="p-4 w-80 ">
        <li class=" mb-4 ">
          <.link
            navigate={~p"/budgets"}
            class="flex items space-x-2 text-base-content hover:text-primary"
          >
            <.icon name="hero-book-open" class="size-6" />

            <span class="sidebar-text hidden md:inline">Orçamentos</span>
          </.link>
        </li>
        <%= if @budget_id do %>
          <li class=" mb-4 ">
            <.link
              navigate={~p"/budgets/#{@budget_id}"}
              class="flex items
            space-x-2 text-base-content hover:text-primary"
            >
              <.icon name="hero-home" class="size-6" />
              <span class="sidebar-text md:inline hidden">Home</span>
            </.link>
          </li>
          <li class=" mb-4 ">
            <.link
              navigate={~p"/budgets/#{@budget_id}/transactions"}
              class="flex items space-x-2 text-base-content hover:text-primary"
            >
              <.icon name="hero-clipboard-document-list" class="size-6" />
              <span class="sidebar-text hidden md:inline">Transações</span>
            </.link>
          </li>
          <li class=" mb-4 ">
            <.link
              navigate={~p"/budgets/#{@budget_id}/profiles"}
              class="flex items space-x-2 text-base-content hover:text-primary"
            >
              <.icon name="hero-users" class="size-6" />
              <span class="sidebar-text hidden md:inline">Perfis</span>
            </.link>
          </li>
          <li class=" mb-4 ">
            <.link
              navigate={~p"/budgets/#{@budget_id}/categories"}
              class="flex items space-x-2 text-base-content hover:text-primary"
            >
              <.icon name="hero-tag" class="size-6" />
              <span class="sidebar-text hidden md:inline">Categorias</span>
            </.link>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  def page_header(assigns) do
    ~H"""
    <ul class="w-full flex items-center gap-4 px-4 sm:px-6 lg:px-8 py-1 sm:py-2 lg:py-3 justify-end medium">
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
    """
  end
end
