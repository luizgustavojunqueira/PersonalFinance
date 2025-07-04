defmodule PersonalFinanceWeb.ProfileLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Profile

  @impl true
  def mount(params, _session, socket) do
    budget = Finance.get_budget(socket.assigns.current_scope, params["id"])

    if budget == nil do
      {:ok,
       socket
       |> put_flash(:error, "Orçamento não encontrado.")
       |> push_navigate(to: ~p"/budgets")}
    else
      socket =
        stream(
          socket,
          :profile_collection,
          Finance.list_profiles(socket.assigns.current_scope, budget)
        )

      {:ok,
       socket
       |> assign(budget: budget)
       |> apply_action(socket.assigns.live_action, params, budget)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> apply_action(socket.assigns.live_action, params, socket.assigns.budget)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params, budget) do
    assign(socket,
      page_title: "Perfis - #{budget.name}",
      profile: nil,
      show_form_modal: false,
      form_action: nil
    )
  end

  defp apply_action(socket, :new, _params, budget) do
    profile = %Profile{budget_id: budget.id}

    assign(socket,
      page_title: "Novo Perfil",
      profile: profile,
      form_action: :new,
      show_form_modal: true,
      form:
        to_form(
          Finance.change_profile(
            socket.assigns.current_scope,
            profile,
            budget
          )
        )
    )
  end

  defp apply_action(socket, :edit, %{"profile_id" => profile_id}, budget) do
    profile = Finance.get_profile(socket.assigns.current_scope, budget.id, profile_id)

    if profile == nil do
      socket
      |> put_flash(:error, "Perfil não encontrado.")
      |> push_navigate(to: ~p"/budgets/#{budget.id}/profiles")
    else
      assign(socket,
        page_title: "Edit Profile",
        profile: profile,
        form_action: :edit,
        show_form_modal: true,
        form:
          to_form(
            Finance.change_profile(
              socket.assigns.current_scope,
              profile,
              budget
            )
          )
      )
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    profile =
      Finance.get_profile(current_scope, socket.assigns.budget.id, id)

    case Finance.delete_profile(current_scope, profile) do
      {:ok, profile} ->
        send(self(), {:profile_deleted, profile})
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao remover o perfil.")}
    end
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply,
     socket
     |> assign(show_form_modal: false, profile: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets/#{socket.assigns.budget.id}/profiles")}
  end

  @impl true
  def handle_event("save", %{"profile" => profile_params}, socket) do
    save_profile(socket, socket.assigns.form_action, profile_params)
  end

  @impl true
  def handle_event("validate", %{"profile" => profile_params}, socket) do
    changeset =
      Finance.change_profile(
        socket.assigns.current_scope,
        socket.assigns.profile,
        socket.assigns.budget,
        profile_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  defp save_profile(socket, :edit, profile_params) do
    case Finance.update_profile(
           socket.assigns.current_scope,
           socket.assigns.profile,
           profile_params
         ) do
      {:ok, profile} ->
        send(self(), {:profile_saved, profile})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_profile(socket, :new, profile_params) do
    case Finance.create_profile(
           socket.assigns.current_scope,
           profile_params,
           socket.assigns.budget
         ) do
      {:ok, profile} ->
        send(self(), {:profile_saved, profile})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Profile Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_info({:profile_saved, profile}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Perfil #{profile.name} salvo com sucesso.")
     |> stream_insert(:profile_collection, profile)
     |> assign(show_form_modal: false, profile: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets/#{socket.assigns.budget.id}/profiles")}
  end

  @impl true
  def handle_info({:profile_deleted, profile}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Perfil removido com sucesso.")
     |> stream_delete(:profile_collection, profile)}
  end
end
