defmodule PersonalFinanceWeb.ProfileLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Finance.Profile

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

      socket =
        stream(
          socket,
          :profile_collection,
          Finance.list_profiles(socket.assigns.current_scope, ledger)
        )

      {:ok,
       socket
       |> assign(ledger: ledger)
       |> apply_action(socket.assigns.live_action, params, ledger)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> apply_action(socket.assigns.live_action, params, socket.assigns.ledger)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params, ledger) do
    assign(socket,
      page_title: "Perfis - #{ledger.name}",
      profile: nil,
      show_form_modal: false,
      show_delete_modal: false,
      form_action: nil
    )
  end

  defp apply_action(socket, :new, _params, ledger) do
    profile = %Profile{ledger_id: ledger.id}

    assign(socket,
      page_title: "Novo Perfil",
      profile: profile,
      form_action: :new,
      show_form_modal: true,
      show_delete_modal: false,
      form:
        to_form(
          Finance.change_profile(
            socket.assigns.current_scope,
            profile,
            ledger
          )
        )
    )
  end

  defp apply_action(socket, :edit, %{"profile_id" => profile_id}, ledger) do
    profile = Finance.get_profile(socket.assigns.current_scope, ledger.id, profile_id)

    if profile == nil do
      socket
      |> put_flash(:error, "Perfil não encontrado.")
      |> push_navigate(to: ~p"/ledgers/#{ledger.id}/profiles")
    else
      assign(socket,
        page_title: "Edit Profile",
        profile: profile,
        form_action: :edit,
        show_form_modal: true,
        show_delete_modal: false,
        form:
          to_form(
            Finance.change_profile(
              socket.assigns.current_scope,
              profile,
              ledger
            )
          )
      )
    end
  end

  defp apply_action(socket, :delete, %{"profile_id" => profile_id}, ledger) do
    profile = Finance.get_profile(socket.assigns.current_scope, ledger.id, profile_id)

    assign(socket,
      page_title: "Categorias - #{ledger.name}",
      ledger: ledger,
      show_form_modal: false,
      show_delete_modal: true,
      profile: profile,
      form_action: nil
    )
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    profile =
      Finance.get_profile(current_scope, socket.assigns.ledger.id, id)

    case Finance.delete_profile(current_scope, profile) do
      {:ok, _profile} ->
        {:noreply,
         Phoenix.LiveView.push_patch(socket,
           to: ~p"/ledgers/#{socket.assigns.ledger.id}/profiles"
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Falha ao remover o perfil.")}
    end
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply,
     socket
     |> assign(show_form_modal: false, profile: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers/#{socket.assigns.ledger.id}/profiles")}
  end

  @impl true
  def handle_event("close_confirmation", _params, socket) do
    {:noreply,
     socket
     |> assign(show_delete_modal: false, profile: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers/#{socket.assigns.ledger.id}/profiles")}
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
        socket.assigns.ledger,
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
      {:ok, _profile} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_profile(socket, :new, profile_params) do
    case Finance.create_profile(
           socket.assigns.current_scope,
           profile_params,
           socket.assigns.ledger
         ) do
      {:ok, _profile} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "Profile Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_info({:saved, profile}, socket) do
    {:noreply,
     socket
     |> stream_insert(:profile_collection, profile)
     |> assign(show_form_modal: false, profile: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers/#{socket.assigns.ledger.id}/profiles")}
  end

  @impl true
  def handle_info({:deleted, profile}, socket) do
    {:noreply,
     socket
     |> stream_delete(:profile_collection, profile)}
  end
end
