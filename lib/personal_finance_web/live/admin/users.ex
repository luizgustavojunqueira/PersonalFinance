defmodule PersonalFinanceWeb.AdminLive.Users do
  use PersonalFinanceWeb, :live_view
  alias PersonalFinance.Accounts
  alias PersonalFinance.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} show_sidebar={true} ledger={nil}>
      <.header>
        User Management
        <:actions>
          <.link patch={~p"/admin/users/new"}>
            <.button>New User</.button>
          </.link>
        </:actions>
      </.header>

      <.table id="users" rows={@users}>
        <:col :let={user} label="Name">{user.name}</:col>
        <:col :let={user} label="Email">{user.email}</:col>
        <:col :let={user} label="Role">
          <span class={[
            "px-2 py-1 text-xs rounded",
            user.role == "admin" && "bg-red-100 text-red-800",
            user.role == "user" && "bg-blue-100 text-blue-800"
          ]}>
            {user.role}
          </span>
        </:col>
        <:col :let={user} label="Created">
          {Calendar.strftime(user.inserted_at, "%b %d, %Y")}
        </:col>
        <:action :let={user}>
          <.link navigate={~p"/admin/users/#{user.id}/edit"} title="Edit User">
            <.icon name="hero-pencil" class="text-blue-600 hover:text-blue-800" />
          </.link>
        </:action>
        <:action :let={user}>
          <.link navigate={~p"/admin/users/#{user.id}/delete"}>
            <.icon name="hero-trash" class="text-red-600 hover:text-red-800" />
          </.link>
        </:action>
      </.table>

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
    users = Accounts.list_users_except(socket.assigns.current_scope.user.id)
    {:ok, assign(socket, users: users)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    user = Accounts.get_user!(id)
    page_title = "Edit User: #{user.name}"

    assign(socket, page_title: page_title, user: user)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:user, %User{})
  end

  defp apply_action(socket, :delete, %{"id" => id}) do
    user = Accounts.get_user!(id)

    socket
    |> assign(:page_title, "Delete User")
    |> assign(:user, user)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "User Management")
    |> assign(:user, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)

    users = Accounts.list_users_except(socket.assigns.current_scope.user.id)

    {:noreply,
     socket
     |> assign(users: users)
     |> put_flash(:info, "User deleted successfully")
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
end
