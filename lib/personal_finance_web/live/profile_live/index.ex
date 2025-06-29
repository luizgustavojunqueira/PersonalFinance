defmodule PersonalFinanceWeb.ProfileLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.{Profile}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    user_budgets =
      Finance.list_budgets_for_user(current_user)

    current_budget =
      case user_budgets do
        [] -> nil
        [first | _] -> first
      end

    profiles = Finance.list_profiles_for_budget(current_budget)

    changeset = Profile.changeset(%Profile{}, %{})

    socket = assign(socket, changeset: changeset, profiles: profiles)

    {:ok, socket}
  end
end
