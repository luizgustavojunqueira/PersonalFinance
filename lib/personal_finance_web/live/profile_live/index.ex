defmodule PersonalFinanceWeb.ProfileLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.{Profile}

  @impl true
  def mount(%{"id" => budget_id}, _session, socket) do
    current_budget = Finance.get_budget_by_id(budget_id)

    profiles = Finance.list_profiles_for_budget(current_budget)

    changeset = Profile.changeset(%Profile{}, %{})

    socket =
      assign(socket,
        changeset: changeset,
        profiles: profiles,
        budget_id: budget_id,
        current_budget: current_budget
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("delete_profile", %{"id" => id}, socket) do
    case Finance.delete_profile_by_id(id) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile deleted successfully.")
         |> redirect(to: ~p"/budgets/#{socket.assigns.budget_id}/profiles")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete profile.")}
    end
  end

  @impl true
  def handle_event("edit_profile", %{"id" => id}, socket) do
    {:noreply, redirect(socket, to: ~p"/budgets/#{socket.assigns.budget_id}/profiles/#{id}/edit")}
  end
end
