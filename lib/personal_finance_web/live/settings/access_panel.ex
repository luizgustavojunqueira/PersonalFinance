defmodule PersonalFinanceWeb.SettingsLive.AccessPanel do
  use PersonalFinanceWeb, :live_component

  alias PersonalFinanceWeb.SettingsLive.{CollaboratorsList, InviteForm}

  @impl true
  def update(assigns, socket) do
    parent_pid =
      assigns
      |> Map.get(:parent_pid)
      |> case do
        nil -> socket.assigns[:parent_pid] || self()
        pid -> pid
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:parent_pid, parent_pid)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid gap-6 grid-cols-1 lg:grid-cols-[minmax(0,40%)_minmax(0,60%)]">
      <.live_component
        module={InviteForm}
        id={"#{@id}-invite-form"}
        ledger={@ledger}
        current_scope={@current_scope}
        parent_pid={@parent_pid}
      />

      <.live_component
        module={CollaboratorsList}
        id={"#{@id}-collaborators"}
        ledger={@ledger}
        current_scope={@current_scope}
        parent_pid={@parent_pid}
      />
    </div>
    """
  end
end
