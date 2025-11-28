defmodule PersonalFinanceWeb.ProfileLive.Index do
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

      {:ok,
       socket
       |> assign(ledger: ledger, open_modal: nil, profile: nil)
       |> stream(
         :profile_collection,
         Finance.list_profiles(socket.assigns.current_scope, ledger)
       )}
    end
  end

  @impl true
  def handle_event("open_modal", %{"modal" => modal}, socket) do
    modal_atom = String.to_existing_atom(modal)
    {:noreply, assign(socket, open_modal: modal_atom, profile: nil)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, open_modal: nil, profile: nil)}
  end

  @impl true
  def handle_event("open_edit_profile", %{"profile_id" => profile_id}, socket) do
    ledger = socket.assigns.ledger

    profile = Finance.get_profile(socket.assigns.current_scope, ledger.id, profile_id)

    if profile == nil do
      socket
      |> put_flash(:error, "Perfil não encontrado.")
      |> push_navigate(to: ~p"/ledgers/#{ledger.id}/profiles")
    else
      {:noreply,
       socket
       |> assign(
         page_title: "Edit Profile",
         profile: profile,
         open_modal: :edit_profile,
         form:
           to_form(
             Finance.change_profile(
               socket.assigns.current_scope,
               profile,
               ledger
             )
           )
       )}
    end
  end

  @impl true
  def handle_event("open_delete_modal", %{"profile_id" => profile_id}, socket) do
    current_scope = socket.assigns.current_scope

    profile =
      Finance.get_profile(current_scope, socket.assigns.ledger.id, profile_id)

    if profile do
      {:noreply,
       assign(socket,
         open_modal: :delete_profile,
         profile: profile
       )}
    else
      {:noreply, put_flash(socket, :error, "profile not found.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    profile =
      Finance.get_profile(current_scope, socket.assigns.ledger.id, id)

    case Finance.delete_profile(current_scope, profile) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> assign(open_modal: nil, profile: nil)
         |> put_flash(:info, "Perfil removido com sucesso.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao remover o perfil.")}
    end
  end

  @impl true
  def handle_info({:saved, profile}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Perfil salvo com sucesso.")
     |> stream_insert(:profile_collection, profile)
     |> assign(open_modal: false, profile: nil)}
  end

  @impl true
  def handle_info({:deleted, profile}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Perfil removido com sucesso.")
     |> stream_delete(:profile_collection, profile)}
  end
end
