defmodule PersonalFinanceWeb.TransactionLive.Import do
  use PersonalFinanceWeb, :live_component
  alias PersonalFinance.Finance
  alias PersonalFinanceWeb.TransactionLive.Transactions

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> allow_upload(:file,
       accept: ~w(.csv),
       max_entries: 1,
       max_file_size: 5_000_000
     )
     |> assign(:import_form, to_form(%{"file" => nil}, as: :import_form))
     |> assign(:imported_transactions, [])
     |> assign(:imported_count, 0)
     |> assign(:importing, false)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal
        show={@show}
        id={@id}
        on_close={JS.push("close_modal")}
        class="mt-2"
      >
        <:title>
          <span class="flex items-center gap-2">
            <.icon name="hero-document-arrow-up" class="w-6 h-6" /> {gettext("Import Transactions")}
          </span>
        </:title>
        <div class="p-6">
          <.form
            for={@import_form}
            id="import-form"
            phx-submit="import_transactions"
            phx-change="validate_import"
            phx-target={@myself}
            class="space-y-4"
          >
            <div class="form-control">
              <label class="label">
                <span class="label-text font-medium">{gettext("CSV File")}</span>
              </label>
              <label
                for={@uploads.file.ref}
                phx-drop-target={@uploads.file.ref}
                class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors duration-300 cursor-pointer flex flex-col items-center"
              >
                <.icon
                  name="hero-cloud-arrow-up"
                  class="w-12 h-12 mb-4 text-base-content/50"
                />
                <p class="text-base font-medium text-base-content">
                  {gettext("Drag and drop your CSV file")}
                </p>
                <p class="text-sm text-base-content/70 mt-1">
                  {gettext("or click to select (maximum 5MB)")}
                </p>
                <.live_file_input
                  upload={@uploads.file}
                  class="sr-only"
                />
              </label>

              <%= for entry <- @uploads.file.entries do %>
                <div class="mt-4">
                  <div class="flex justify-between text-sm mb-1">
                    <span>{entry.client_name}</span>
                    <span>{entry.progress}%</span>
                  </div>
                  <progress class="progress progress-primary" value={entry.progress} max="100">
                  </progress>
                </div>
              <% end %>

              <%= for err <- upload_errors(@uploads.file) do %>
                <div class="alert alert-error mt-2">
                  <.icon name="hero-exclamation-triangle" class="w-4 h-4" />
                  <span>
                    <%= case err do %>
                      <% :too_large -> %>
                        {gettext("File too large (maximum 5MB)")}
                      <% :not_accepted -> %>
                        {gettext("File type not accepted (CSV only)")}
                      <% :too_many_files -> %>
                        {gettext("Only one file at a time")}
                      <% _ -> %>
                        {gettext("Upload error")}
                    <% end %>
                  </span>
                </div>
              <% end %>
            </div>

            <div classs="flex flex-row gap-2 mt-4 w-full">
              <.button
                type="submit"
                disabled={@uploads.file.entries == [] or @importing}
                variant="custom"
                class="btn btn-primary w-full"
              >
                <%= if @importing do %>
                  <span class="loading loading-spinner loading-sm"></span> {gettext("Importing...")}
                <% else %>
                  <.icon name="hero-document-arrow-up" class="w-4 h-4" /> {gettext("Import")}
                <% end %>
              </.button>
            </div>
          </.form>

          <%= if @imported_count > 0 do %>
            <div class="divider">{gettext("Imported Transactions")}</div>
            <div class="bg-success/10 border border-success/20 rounded-lg p-4 mb-4">
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-check-circle" class="w-5 h-5 text-success" />
                <span class="font-medium text-success">
                  {Gettext.ngettext(PersonalFinanceWeb.Gettext, "%{count} transaction successfully imported!", "%{count} transactions successfully imported!", @imported_count, count: @imported_count)}
                </span>
              </div>
            </div>
          <% end %>
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("import_transactions", _params, socket) do
    socket = assign(socket, :importing, true)

    results =
      consume_uploaded_entries(socket, :file, fn %{path: path}, _entry ->
        Finance.import_transactions(socket.assigns.current_scope, %Plug.Upload{path: path})
      end)

    case results do
      [transactions] when is_list(transactions) ->
        send_update(Transactions,
          id: "transactions-list",
          action: :update,
          filter: %{}
        )

        {:noreply,
         socket
         |> assign(:imported_transactions, transactions)
         |> assign(:imported_count, length(transactions))
         |> assign(:importing, false)
         |> put_flash(:info, Gettext.ngettext(PersonalFinanceWeb.Gettext, "%{count} transaction successfully imported!", "%{count} transactions successfully imported!", length(transactions), count: length(transactions)))}

      [{:error, reason}] ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, "#{gettext("Error importing transactions")}: #{inspect(reason)}")
         |> assign(:imported_transactions, [])
         |> assign(:imported_count, 0)}

      [] ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, gettext("No file was processed."))
         |> assign(:imported_transactions, [])
         |> assign(:imported_count, 0)}

      _ ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, gettext("Unexpected result structure."))
         |> assign(:imported_transactions, [])
         |> assign(:imported_count, 0)}
    end
  end

  @impl true
  def handle_event("validate_import", _params, socket) do
    {:noreply, socket}
  end
end
