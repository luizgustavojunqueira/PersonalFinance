defmodule PersonalFinanceWeb.AdminLive.Users do
  use PersonalFinanceWeb, :live_view
  alias PersonalFinance.Accounts
  alias PersonalFinance.Accounts.User
  alias PersonalFinance.Utils.DateUtils

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} show_sidebar={true} ledger={nil}>
      <div class="space-y-10">
        <section class="rounded-3xl border border-base-300 bg-base-100/70 p-8 shadow-sm backdrop-blur mt-4">
          <div class="flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
            <div class="space-y-2">
              <p class="text-sm font-medium text-base-content/60 uppercase tracking-wide">
                {gettext("Team Access")}
              </p>
              <h1 class="text-3xl font-semibold text-base-content">
                {gettext("User Management")}
              </h1>
              <p class="text-base text-base-content/70">
                {gettext("Invite teammates, define roles and keep your back-office tidy.")}
              </p>
            </div>

            <div class="flex flex-col gap-4 sm:flex-row sm:items-center">
              <.link patch={~p"/admin/users/new"}>
                <.button class="btn-primary gap-2">
                  <.icon name="hero-plus-mini" class="h-4 w-4" />
                  {gettext("Add Teammate")}
                </.button>
              </.link>
            </div>
          </div>
        </section>

        <section class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <div class="rounded-2xl border border-base-200 bg-base-100 p-5">
            <p class="text-sm text-base-content/60">{gettext("Total Users")}</p>
            <p class="mt-2 text-3xl font-semibold text-base-content">{@stats.total}</p>
          </div>
          <div class="rounded-2xl border border-base-200 bg-base-100 p-5">
            <p class="text-sm text-base-content/60">{gettext("Administrators")}</p>
            <p class="mt-2 text-3xl font-semibold text-base-content">{@stats.admins}</p>
          </div>
          <div class="rounded-2xl border border-base-200 bg-base-100 p-5">
            <p class="text-sm text-base-content/60">{gettext("Members")}</p>
            <p class="mt-2 text-3xl font-semibold text-base-content">{@stats.members}</p>
          </div>
        </section>

        <section class="rounded-3xl border border-base-300 bg-base-100/80 p-6 shadow-sm">
          <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div>
              <p class="text-sm font-medium text-base-content/60">{gettext("Directory")}</p>
              <p class="text-base text-base-content/70">
                {gettext("All collaborators currently allowed to use the platform.")}
              </p>
            </div>
            <div class="flex gap-3 text-sm text-base-content/60">
              <span class="rounded-full border border-base-200 px-3 py-1">
                {ngettext("%{count} person", "%{count} people", length(@users), count: length(@users))}
              </span>
              <span class="rounded-full border border-base-200 px-3 py-1">
                {gettext("Sorted by most recent")}
              </span>
            </div>
          </div>

          <div class="mt-6 divide-y divide-base-200">
            <div
              :for={user <- @users}
              class="flex bg-base-200 px-2 mb-2 rounded-2xl flex-col gap-4 py-4 md:flex-row md:items-center md:justify-between"
            >
              <div class="flex flex-1 flex-col gap-1">
                <div class="flex items-center gap-2">
                  <p class="text-base font-semibold text-base-content">{user.name}</p>
                  <span class={role_badge_classes(user.role)}>
                    {role_label(user.role)}
                  </span>
                </div>
                <p class="text-sm text-base-content/70">{user.email}</p>
              </div>

              <div class="flex flex-1 flex-col gap-1 text-sm text-base-content/70 md:flex-row md:items-center md:justify-end md:text-right">
                <p>
                  {gettext("Joined %{date}", date: format_joined_at(user.inserted_at))}
                </p>
              </div>

              <div class="flex items-center gap-3">
                <.link navigate={~p"/admin/users/#{user.id}/edit"} title={gettext("Edit user")}
                >
                  <.button class="btn-ghost btn-sm gap-1 text-xs">
                    <.icon name="hero-pencil-square" class="h-4 w-4" />
                    {gettext("Edit")}
                  </.button>
                </.link>
                <.link navigate={~p"/admin/users/#{user.id}/delete"} title={gettext("Delete user")}>
                  <.button class="btn-ghost btn-sm gap-1 text-xs text-error">
                    <.icon name="hero-trash" class="h-4 w-4" />
                    {gettext("Delete")}
                  </.button>
                </.link>
              </div>
            </div>

            <div :if={Enum.empty?(@users)} class="flex flex-col items-center gap-3 py-12 text-center">
              <div class="rounded-full bg-base-200 p-4 text-base-content/60">
                <.icon name="hero-user-plus" class="h-6 w-6" />
              </div>
              <p class="text-lg font-medium text-base-content">
                {gettext("There are no additional users yet.")}
              </p>
              <p class="max-w-md text-sm text-base-content/70">
                {gettext("Invite your first collaborator to unlock shared bookkeeping and approvals.")}
              </p>
              <.link patch={~p"/admin/users/new"}>
                <.button class="btn-primary btn-sm gap-2">
                  <.icon name="hero-plus-mini" class="h-4 w-4" />
                  {gettext("Invite someone")}
                </.button>
              </.link>
            </div>
          </div>
        </section>
      </div>

      <div :if={@live_action in [:new, :edit]}>
        <.live_component
          module={PersonalFinanceWeb.AdminLive.UserFormComponent}
          id={@user.id || :new}
          title={@page_title}
          action={@live_action}
          user={@user}
          navigate={~p"/admin/users"}
        />
      </div>

      <div :if={@live_action == :delete} id="delete-modal">
        <.confirmation_modal
          title="Excluir Usuário"
          message={"Tem certeza que deseja excluir o usuário #{@user.name}? Isso ira remover permanentemente todos os seus ledgers. Esta ação não pode ser desfeita."}
          confirm_event="delete"
          cancel_event="close_confirmation"
          item_id={@user.id}
        />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, refresh_directory(socket)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    if current_user_id?(socket, id) do
      socket
      |> put_flash(:error, gettext("You cannot edit your own access level."))
      |> assign(:user, nil)
      |> push_patch(to: ~p"/admin/users")
    else
      user = Accounts.get_user!(id)
      page_title = gettext("Edit User: %{name}", name: user.name)

      assign(socket, page_title: page_title, user: user)
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New User"))
    |> assign(:user, %User{})
  end

  defp apply_action(socket, :delete, %{"id" => id}) do
    user = Accounts.get_user!(id)

    socket
    |> assign(:page_title, gettext("Delete User"))
    |> assign(:user, user)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("User Management"))
    |> assign(:user, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)

    {:noreply,
     socket
     |> refresh_directory()
     |> put_flash(:info, gettext("User deleted successfully"))
     |> push_patch(to: ~p"/admin/users")}
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply,
     socket
     |> assign(user: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/admin/users")}
  end

  @impl true
  def handle_event("close_confirmation", _params, socket) do
    {:noreply,
     socket
     |> assign(user: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/admin/users")}
  end

  defp refresh_directory(socket) do
    current_user = socket.assigns.current_scope.user
    users = Accounts.list_users()
    stats = stats_for(users, current_user)

    socket
    |> assign(
      users: users,
      stats: stats
    )
  end

  defp stats_for(users, current_user) do
    total = length(users)
    admins = Enum.count(users, &(&1.role == "admin"))
    members = max(total - admins, 0)
    recent = Enum.max_by(users, & &1.inserted_at, fn -> current_user end)
    %{total: total, admins: admins, members: members, recent: recent}
  end


  defp role_badge_classes("admin") do
    "rounded-full bg-error/10 text-error px-3 py-1 text-xs font-medium"
  end

  defp role_badge_classes(_role) do
    "rounded-full bg-primary/10 text-primary px-3 py-1 text-xs font-medium"
  end

  defp role_label(role) when is_binary(role), do: String.capitalize(role)
  defp role_label(role) when is_atom(role), do: role |> Atom.to_string() |> role_label()
  defp role_label(_role), do: "--"

  defp current_user_id?(socket, id) do
    to_string(socket.assigns.current_scope.user.id) == to_string(id)
  end

  defp format_joined_at(%DateTime{} = datetime) do
    DateUtils.format_date(datetime)
  end

  defp format_joined_at(%NaiveDateTime{} = datetime) do
    DateUtils.format_date(datetime)
  end

  defp format_joined_at(_), do: "--"
end
