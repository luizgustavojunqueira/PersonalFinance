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
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div class="bg-base-100 rounded-lg shadow-xl w-full max-w-2xl mx-4 max-h-[90vh] overflow-y-auto">
        <div class="flex items-center justify-between p-6 border-b border-base-200">
          <h2 class="text-2xl font-bold text-base-content">
            <.icon name="hero-document-arrow-up" class="w-6 h-6 inline mr-2" /> Importar Transações
          </h2>
          <button
            phx-click="toggle_import_modal"
            class="btn btn-ghost btn-sm btn-circle"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <div class="p-6">
          <div class="mb-6">
            <.form
              for={@import_form}
              phx-submit="import_transactions"
              phx-change="validate_import"
              phx-target={@myself}
              class="space-y-4"
            >
              <div class="form-control">
                <label class="label">
                  <span class="label-text font-medium">Arquivo CSV</span>
                </label>
                <div class="border-2 border-dashed border-base-300 rounded-lg p-8 text-center hover:border-primary transition-colors">
                  <.icon
                    name="hero-cloud-arrow-up"
                    class="w-12 h-12 mx-auto mb-4 text-base-content/50"
                  />
                  <.live_file_input
                    upload={@uploads.file}
                    class="file-input file-input-bordered file-input-primary w-full"
                  />
                  <p class="text-sm text-base-content/70 mt-2">
                    Selecione um arquivo CSV (máximo 5MB)
                  </p>
                </div>

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
                          Arquivo muito grande (máximo 5MB)
                        <% :not_accepted -> %>
                          Tipo de arquivo não aceito (apenas CSV)
                        <% :too_many_files -> %>
                          Apenas um arquivo por vez
                        <% _ -> %>
                          Erro no upload
                      <% end %>
                    </span>
                  </div>
                <% end %>
              </div>

              <div class="flex justify-end gap-2">
                <button
                  type="button"
                  phx-click="toggle_import_modal"
                  class="btn btn-outline"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  disabled={@uploads.file.entries == [] or @importing}
                  class="btn btn-primary"
                >
                  <%= if @importing do %>
                    <span class="loading loading-spinner loading-sm"></span> Importando...
                  <% else %>
                    <.icon name="hero-document-arrow-up" class="w-4 h-4" /> Importar
                  <% end %>
                </button>
              </div>
            </.form>
          </div>
          <%= if @imported_count > 0 do %>
            <div class="divider">Transações Importadas</div>

            <div class="bg-success/10 border border-success/20 rounded-lg p-4 mb-4">
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-check-circle" class="w-5 h-5 text-success" />
                <span class="font-medium text-success">
                  {@imported_count} transações importadas com sucesso!
                </span>
              </div>
            </div>
          <% end %>
        </div>
      </div>
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

    IO.inspect(results, label: "Results from consume_uploaded_entries")

    case results do
      [transactions] when is_list(transactions) ->
        IO.inspect(transactions, label: "Imported Transactions")

        # Notifica o componente de transações para atualizar
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
         |> put_flash(:info, "#{length(transactions)} transações importadas com sucesso!")}

      [{:error, reason}] ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, "Erro ao importar transações: #{inspect(reason)}")
         |> assign(:imported_transactions, [])
         |> assign(:imported_count, 0)}

      [] ->
        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, "Nenhum arquivo foi processado.")
         |> assign(:imported_transactions, [])
         |> assign(:imported_count, 0)}

      _ ->
        IO.inspect(results, label: "Unexpected results structure")

        {:noreply,
         socket
         |> assign(:importing, false)
         |> put_flash(:error, "Estrutura de resultado inesperada.")
         |> assign(:imported_transactions, [])
         |> assign(:imported_count, 0)}
    end
  end

  @impl true
  def handle_event("validate_import", _params, socket) do
    {:noreply, socket}
  end
end
