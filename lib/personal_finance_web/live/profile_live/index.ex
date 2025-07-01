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
end
