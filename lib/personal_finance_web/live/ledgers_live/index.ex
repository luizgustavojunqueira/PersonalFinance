defmodule PersonalFinanceWeb.LedgersLive.Index do
  alias PersonalFinance.Finance.Ledger
  alias PersonalFinance.Finance
  use PersonalFinanceWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> stream(:ledger_collection, Finance.list_ledgers(current_scope))

    {:ok, socket |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket,
      page_title: "Ledgers",
      show_form_modal: false,
      show_delete_modal: false,
      ledger: nil
    )
  end

  defp apply_action(socket, :new, _params) do
    ledger = %Ledger{owner_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(
      page_title: "Ledgers",
      show_form_modal: true,
      show_delete_modal: false,
      form_action: :new,
      ledger: ledger,
      form:
        to_form(
          Finance.change_ledger(
            socket.assigns.current_scope,
            ledger
          )
        )
    )
    |> push_event("open_modal:modal_new_ledger", %{})
  end

  defp apply_action(socket, :edit, %{"id" => ledger_id}) do
    ledger = Finance.get_ledger(socket.assigns.current_scope, ledger_id)

    if ledger == nil do
      socket
      |> put_flash(:error, "Ledger não encontrado.")
      |> push_navigate(to: ~p"/ledgers")
    else
      socket
      |> assign(
        page_title: "Ledgers",
        show_form_modal: true,
        show_delete_modal: false,
        form_action: :edit,
        ledger: ledger,
        form:
          to_form(
            Finance.change_ledger(
              socket.assigns.current_scope,
              ledger
            )
          )
      )
      |> push_event("open_modal:modal_new_ledger", %{})
    end
  end

  defp apply_action(socket, :delete, %{"id" => ledger_id}) do
    ledger = Finance.get_ledger(socket.assigns.current_scope, ledger_id)

    assign(socket,
      page_title: "Ledgers",
      ledger: ledger,
      show_form_modal: false,
      show_delete_modal: true,
      form_action: nil
    )
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply,
     socket
     |> assign(show_form_modal: false, ledger: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers")}
  end

  @impl true
  def handle_event("close_confirmation", _params, socket) do
    {:noreply,
     socket
     |> assign(show_delete_modal: false, ledger: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers")}
  end

  @impl true
  def handle_event("save", %{"ledger" => ledger_params}, socket) do
    save_ledger(socket, socket.assigns.form_action, ledger_params)
  end

  @impl true
  def handle_event("validate", %{"ledger" => ledger_params}, socket) do
    changeset =
      Finance.change_ledger(
        socket.assigns.current_scope,
        socket.assigns.ledger,
        ledger_params
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns.current_scope

    ledger = PersonalFinance.Finance.get_ledger(current_scope, id)

    case PersonalFinance.Finance.delete_ledger(current_scope, ledger) do
      {:ok, _deleted} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ledger excluído com sucesso.")
         |> stream_delete(:ledger_collection, ledger)
         |> Phoenix.LiveView.push_patch(to: ~p"/ledgers")}

      {:error, _changeset} ->
        {:noreply, assign(socket, show_menu: false)}
    end
  end

  defp save_ledger(socket, :edit, ledger_params) do
    case Finance.update_ledger(
           socket.assigns.current_scope,
           socket.assigns.ledger,
           ledger_params
         ) do
      {:ok, ledger} ->
        send(self(), {:saved, ledger})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_ledger(socket, :new, ledger_params) do
    case Finance.create_ledger(
           socket.assigns.current_scope,
           ledger_params
         ) do
      {:ok, ledger} ->
        Finance.create_default_profiles(socket.assigns.current_scope, ledger)

        Finance.create_default_categories(socket.assigns.current_scope, ledger)

        send(self(), {:saved, ledger})
        {:noreply, socket}

      {:error, changeset} ->
        IO.inspect(changeset, label: "Ledger Changeset Error")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_info({:saved, ledger}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Ledger salvo com sucesso.")
     |> stream_insert(:ledger_collection, ledger)
     |> assign(show_form_modal: false, category: nil, form_action: nil)
     |> Phoenix.LiveView.push_patch(to: ~p"/ledgers")}
  end
end
