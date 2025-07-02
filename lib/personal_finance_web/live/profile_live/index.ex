defmodule PersonalFinanceWeb.ProfileLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance

  @impl true
  def mount(%{"id" => budget_id}, _session, socket) do
    current_budget = Finance.get_budget!(socket.assigns.current_scope, budget_id)

    {:ok,
     socket
     |> assign(
       page_title: "Profiles for #{current_budget.name}",
       budget: current_budget
     )
     |> stream(:profile_collection, Finance.list_profiles_for_budget(current_budget))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    profile =
      Finance.get_profile!(current_scope, socket.assigns.budget.id, id)

    case Finance.delete_profile(current_scope, profile) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Perfil removido com sucesso.")
         |> stream_delete(:profile_collection, profile)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao remover o perfil.")}
    end
  end
end
