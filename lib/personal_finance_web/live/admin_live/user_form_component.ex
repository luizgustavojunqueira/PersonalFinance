defmodule PersonalFinanceWeb.AdminLive.UserFormComponent do
  use PersonalFinanceWeb, :live_component
  alias PersonalFinance.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form_modal
        form={@form}
        id="user-form"
        title="Usuário"
        subtitle="Preencha o formulário abaixo para salvar o usuário."
        action={@action}
        parent_pid={@myself}
      >
        <.input field={@form[:name]} type="text" label="Name" autocomplete="name" required />
        <.input field={@form[:email]} type="email" label="Email" autocomplete="username" required />
        <.input
          field={@form[:password]}
          type="password"
          label="Password"
          autocomplete="new-password"
          required={@action == :new}
        />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirm Password"
          autocomplete="new-password"
          required={@action == :new}
        />
        <.input
          field={@form[:role]}
          type="select"
          label="Role"
          options={[{"User", "user"}, {"Admin", "admin"}]}
          required
        />
      </.form_modal>
    </div>
    """
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    changeset =
      case assigns.action do
        :new -> Accounts.change_user_email(user)
        :edit -> Accounts.change_user_email(user)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.User.admin_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    user_params =
      if user_params["password"] == "" do
        Map.drop(user_params, ["password", "password_confirmation"])
      else
        user_params
      end

    case Accounts.admin_create_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user(socket, :new, user_params) do
    case Accounts.admin_create_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
