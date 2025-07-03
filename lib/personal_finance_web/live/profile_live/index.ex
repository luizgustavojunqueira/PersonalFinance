defmodule PersonalFinanceWeb.ProfileLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Profile

  @impl true
  def mount(params, _session, socket) do
    budget = Finance.get_budget!(socket.assigns.current_scope, params["id"])

    socket =
      stream(
        socket,
        :profile_collection,
        Finance.list_profiles(socket.assigns.current_scope, budget)
      )

    {:ok,
     socket
     |> apply_action(socket.assigns.live_action, params)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, %{"id" => budget_id}) do
    current_budget = Finance.get_budget!(socket.assigns.current_scope, budget_id)

    assign(socket,
      page_title: "Perfis - #{current_budget.name}",
      budget: current_budget,
      profile: nil,
      show_form_modal: false,
      form_action: nil
    )
  end

  defp apply_action(socket, :new, %{"id" => budget_id}) do
    case Finance.get_budget!(socket.assigns.current_scope, budget_id) do
      current_budget ->
        profile = %Profile{budget_id: current_budget.id}

        assign(socket,
          page_title: "Novo Perfil",
          budget: current_budget,
          profile: profile,
          form_action: :new,
          show_form_modal: true,
          form:
            to_form(Finance.change_profile(socket.assigns.current_scope, profile, current_budget))
        )
    end
  end

  defp apply_action(socket, :edit, %{"id" => budget_id, "profile_id" => profile_id}) do
    case Finance.get_budget!(socket.assigns.current_scope, budget_id) do
      current_budget ->
        case Finance.get_profile!(socket.assigns.current_scope, budget_id, profile_id) do
          profile ->
            assign(socket,
              page_title: "Edit Profile",
              budget: current_budget,
              profile: profile,
              form_action: :edit,
              show_form_modal: true,
              form:
                to_form(
                  Finance.change_profile(socket.assigns.current_scope, profile, current_budget)
                )
            )
        end
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    profile =
      Finance.get_profile!(current_scope, socket.assigns.budget.id, id)

    case Finance.delete_profile(current_scope, profile) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Perfil removido com sucesso.")
         |> stream_delete(:profile_collection, profile)}

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
  def handle_info({:profile_saved, profile}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Perfil #{profile.name} salvo com sucesso.")
     |> stream_insert(:profile_collection, profile)
     |> assign(show_form_modal: false, profile: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/budgets/#{socket.assigns.budget.id}/profiles")}
  end
end
