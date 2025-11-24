defmodule PersonalFinanceWeb.SettingsLive.ProfilesPanel do
  use PersonalFinanceWeb, :live_component

  alias Phoenix.LiveView.JS
  alias PersonalFinance.Finance
  alias PersonalFinanceWeb.SettingsLive.ProfileForm
  alias PersonalFinanceWeb.SettingsLive.RecurringEntriesPanel

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:profiles, [])
     |> assign(:expanded_profiles, MapSet.new())
     |> assign(:profile_modal_action, nil)
     |> assign(:active_profile, nil)
     |> assign(:delete_profile, nil)
     |> assign(:profiles_empty?, true)}
  end

  @impl true
  def update(%{action: :profile_saved, profile: _profile} = assigns, socket) do
    socket =
      socket
      |> assign_base(assigns)
      |> reload_profiles()
      |> assign(:profile_modal_action, nil)
      |> assign(:active_profile, nil)

    {:ok, socket}
  end

  def update(%{action: :profile_deleted} = assigns, socket) do
    socket =
      socket
      |> assign_base(assigns)
      |> reload_profiles()

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> reload_profiles()

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_profile", %{"profile_id" => profile_id}, socket) do
    profile_id = parse_id(profile_id)

    expanded_profiles =
      if MapSet.member?(socket.assigns.expanded_profiles, profile_id) do
        MapSet.delete(socket.assigns.expanded_profiles, profile_id)
      else
        MapSet.put(socket.assigns.expanded_profiles, profile_id)
      end

    {:noreply, assign(socket, :expanded_profiles, expanded_profiles)}
  end

  @impl true
  def handle_event("open_new_profile", _params, socket) do
    {:noreply,
     socket
     |> assign(:profile_modal_action, :new)
     |> assign(:active_profile, nil)}
  end

  @impl true
  def handle_event("open_edit_profile", %{"profile_id" => profile_id}, socket) do
    with {:ok, profile} <- fetch_profile(socket, profile_id) do
      {:noreply,
       socket
       |> assign(:profile_modal_action, :edit)
       |> assign(:active_profile, profile)}
    else
      :error ->
        send_flash(socket, :error, gettext("Profile not found."))
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_profile_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:profile_modal_action, nil)
     |> assign(:active_profile, nil)}
  end

  @impl true
  def handle_event("open_delete_modal", %{"profile_id" => profile_id}, socket) do
    with {:ok, profile} <- fetch_profile(socket, profile_id) do
      {:noreply, assign(socket, :delete_profile, profile)}
    else
      :error ->
        send_flash(socket, :error, gettext("Profile not found."))
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_delete_modal", _params, socket) do
    {:noreply, assign(socket, :delete_profile, nil)}
  end

  @impl true
  def handle_event("delete_profile", %{"id" => profile_id}, socket) do
    with {:ok, profile} <- fetch_profile(socket, profile_id),
         {:ok, _profile} <- Finance.delete_profile(socket.assigns.current_scope, profile) do
      send_flash(socket, :info, gettext("Profile successfully deleted."))

      {:noreply,
       socket
       |> assign(:delete_profile, nil)
       |> reload_profiles()}
    else
      {:error, _changeset} ->
        send_flash(socket, :error, gettext("Failed to delete profile."))
        {:noreply, socket}

      :error ->
        send_flash(socket, :error, gettext("Profile not found."))
        {:noreply, socket}
    end
  end

  def handle_info({:saved, _profile}, socket) do
    {:noreply,
     socket
     |> reload_profiles()
     |> assign(:profile_modal_action, nil)
     |> assign(:active_profile, nil)}
  end

  def handle_info({:deleted, _profile}, socket) do
    {:noreply, reload_profiles(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="space-y-4">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-2xl font-semibold text-base-content">{gettext("Manage profiles and recurrences")}</p>
          </div>
          <.button
            variant="primary"
            size="sm"
            class="gap-1"
            phx-click="open_new_profile"
            phx-target={@myself}
          >
            <.icon name="hero-plus" class="w-4 h-4 mr-1" /> {gettext("New profile")}
          </.button>
        </div>

        <div class="space-y-2">
          <%= if @profiles_empty? do %>
            <div class="rounded-xl border border-dashed border-base-300 bg-base-100/80 p-6 text-sm text-base-content/70">
              {gettext("No profiles registered yet.")}
            </div>
          <% end %>

          <%= for profile <- @profiles do %>
            <div class="rounded-xl border border-base-300 bg-base-100/70 shadow-sm">
              <div class="flex items-center justify-between gap-4 p-4">
                <button
                  type="button"
                  class="flex flex-1 items-center justify-between text-left"
                  phx-click="toggle_profile"
                  phx-value-profile_id={profile.id}
                  phx-target={@myself}
                >
                  <div class="flex items-center gap-4">
                    <div class="space-y-1">
                      <p class="text-base font-semibold text-base-content">{profile.name}</p>
                      <p class="text-sm text-base-content/70">
                        {profile.description || gettext("No description")}
                      </p>
                    </div>
                  </div>
                  <.icon
                    name="hero-chevron-down"
                    class={"size-5 transition-transform duration-200 #{if profile_expanded?(@expanded_profiles, profile.id), do: "rotate-180", else: ""}"}
                  />
                </button>

                <div class="flex items-center gap-2">
                  <span
                    class="inline-block h-4 w-7 rounded-xl border border-base-content"
                    style={"background-color: #{profile.color};"}
                  />
                  <.button
                    type="button"
                    variant="custom"
                    size="sm"
                    class="btn-circle btn-ghost"
                    phx-click="open_edit_profile"
                    phx-value-profile_id={profile.id}
                    phx-target={@myself}
                    title={gettext("Edit profile")}
                  >
                    <.icon name="hero-pencil" class="text-primary" />
                  </.button>
                  <%= unless profile.is_default do %>
                    <.button
                      type="button"
                      variant="custom"
                      size="sm"
                      class="btn-circle btn-ghost"
                      phx-click="open_delete_modal"
                      phx-value-profile_id={profile.id}
                      phx-target={@myself}
                      title={gettext("Delete profile")}
                    >
                      <.icon name="hero-trash" class="text-error" />
                    </.button>
                  <% end %>
                </div>
              </div>

              <%= if profile_expanded?(@expanded_profiles, profile.id) do %>
                <div class="border-t border-base-300">
                  <div class="px-4 pb-4">
                    <.live_component
                      module={RecurringEntriesPanel}
                      id={"recurring-panel-#{profile.id}"}
                      ledger={@ledger}
                      profile={profile}
                      current_scope={@current_scope}
                      parent_pid={@parent_pid}
                    />
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <.live_component
        module={ProfileForm}
        id="settings-profile-form"
        show={not is_nil(@profile_modal_action)}
        action={@profile_modal_action || :new}
        profile={@active_profile}
        ledger={@ledger}
        current_scope={@current_scope}
        on_close={JS.push("close_profile_modal", target: @myself)}
      />

      <.modal
        id="delete-profile-modal"
        show={not is_nil(@delete_profile)}
        on_close={JS.push("close_delete_modal", target: @myself)}
      >
        <:title>{gettext("Delete profile")}</:title>
        <:content>
          <p class="text-base">
            {gettext("Are you sure you want to delete the profile \"%{name}\"?", name: @delete_profile && @delete_profile.name)}
          </p>
          <p class="mt-2 text-sm text-base-content/70">
            {gettext("All recurring transactions associated with this profile will be permanently deleted.")}
          </p>
        </:content>
        <:actions>
          <.button
            variant="primary"
            phx-click="delete_profile"
            phx-value-id={@delete_profile && @delete_profile.id}
            phx-target={@myself}
          >
            {gettext("Delete")}
          </.button>
          <.button
            variant="custom"
            size="sm"
            class="btn-ghost"
            phx-click="close_delete_modal"
            phx-target={@myself}
          >
            {gettext("Cancel")}
          </.button>
        </:actions>
      </.modal>
    </div>
    """
  end

  defp profile_expanded?(expanded_profiles, profile_id) do
    MapSet.member?(expanded_profiles, profile_id)
  end

  defp fetch_profile(socket, profile_id) do
    case Finance.get_profile(socket.assigns.current_scope, socket.assigns.ledger.id, profile_id) do
      nil -> :error
      profile -> {:ok, profile}
    end
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> int
      :error -> id
    end
  end

  defp parse_id(id), do: id

  defp send_flash(socket, type, message) do
    send(socket.assigns.parent_pid, {:put_flash, type, message})
  end

  defp assign_base(socket, assigns) do
    Enum.reduce([:ledger, :current_scope, :parent_pid], socket, fn key, acc ->
      case Map.fetch(assigns, key) do
        {:ok, value} -> assign(acc, key, value)
        :error -> acc
      end
    end)
  end

  defp reload_profiles(socket) do
    profiles = Finance.list_profiles(socket.assigns.current_scope, socket.assigns.ledger)

    socket
    |> assign(:profiles, profiles)
    |> assign(:profiles_empty?, Enum.empty?(profiles))
  end
end
