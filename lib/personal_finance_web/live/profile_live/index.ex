defmodule PersonalFinanceWeb.ProfileLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.{Profile}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    profiles = Finance.list_profiles_for_user(current_user)

    changeset = Profile.changeset(%Profile{}, %{})

    socket = assign(socket, changeset: changeset, profiles: profiles)

    {:ok, socket}
  end
end
