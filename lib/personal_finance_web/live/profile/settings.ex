defmodule PersonalFinanceWeb.ProfileLive.Settings do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance

  @impl true
  def mount(params, _session, socket) do
    ledger = Finance.get_ledger(socket.assigns.current_scope, params["id"])

    if ledger == nil do
      {:ok,
       socket
       |> put_flash(:error, "Orçamento não encontrado.")
       |> push_navigate(to: ~p"/ledgers")}
    else
      Finance.subscribe_finance(:profile, ledger.id)

      profile = Finance.get_profile(socket.assigns.current_scope, ledger.id, params["profile_id"])

      if profile == nil do
        {:ok,
         socket
         |> put_flash(:error, "Perfil não encontrado.")
         |> push_navigate(to: ~p"/ledgers/#{ledger.id}/profiles")}
      else
        {:ok,
         socket
         |> assign(ledger: ledger, profile: profile)}
      end
    end
  end

  @impl true
  def handle_info({:put_flash, type, message}, socket) do
    {:noreply, socket |> put_flash(type, message)}
  end
end
