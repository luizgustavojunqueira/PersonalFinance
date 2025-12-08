defmodule PersonalFinanceWeb.TransactionLive.ImportWizard do
  use PersonalFinanceWeb, :live_view

  alias Ecto.UUID
  alias PersonalFinance.Finance
  alias PersonalFinance.Utils.{CurrencyUtils, DateUtils, ParseUtils}

  @impl true
  def mount(%{"id" => ledger_id}, _session, socket) do
    current_scope = socket.assigns.current_scope
    ledger = Finance.get_ledger(current_scope, ledger_id)

    if is_nil(ledger) do
      {:ok,
       socket
       |> put_flash(:error, gettext("Ledger not found."))
       |> push_navigate(to: ~p"/ledgers")}
    else
      profiles = Finance.list_profiles(current_scope, ledger)
      categories = Finance.list_categories(current_scope, ledger)
      default_profile = Enum.find(profiles, &(&1.is_default)) || List.first(profiles)
      default_category = Finance.get_default_category(current_scope, ledger.id) || List.first(categories)

      {:ok,
       socket
       |> allow_upload(:file,
         accept: [".csv", "text/csv", "application/vnd.ms-excel", ".xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"],
         max_entries: 1,
         max_file_size: 5_000_000
       )
       |> assign(:ledger, ledger)
       |> assign(:profiles, profiles)
       |> assign(:categories, categories)
       |> assign(:profiles_options, Enum.map(profiles, &{&1.name, &1.id}))
       |> assign(:categories_options, Enum.map(categories, &{&1.name, &1.id}))
       |> assign(:default_profile_id, default_profile && default_profile.id)
       |> assign(:default_category_id, default_category && default_category.id)
       |> assign(:entries, [])
       |> assign(:import_form, to_form(%{"file" => nil}, as: :import_form))
       |> assign(:importing, false)
       |> assign(:page_title, "#{gettext("Import Wizard")} - #{ledger.name}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} show_sidebar={true} ledger={@ledger}>
      <div class="min-h-screen pb-12 space-y-6">
        <section class="bg-base-100/80 border border-base-300 rounded-2xl p-6 shadow-sm mt-4">
          <div class="flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
            <div class="space-y-2">
              <p class="text-sm font-semibold uppercase tracking-wide text-primary/70">
                {gettext("Import Wizard")}
              </p>
              <h1 class="text-3xl font-bold text-base-content">{@ledger.name}</h1>
              <p class="text-sm text-base-content/70">{gettext("This wizard currently supports the provided bank CSV format.")}</p>
            </div>

            <div class="flex flex-wrap gap-2 w-full lg:w-auto">
              <.link class="btn btn-outline" navigate={~p"/ledgers/#{@ledger.id}/transactions"}>
                <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Transactions")}
              </.link>
            </div>
          </div>
        </section>

        <section class="bg-base-100/80 border border-base-300 rounded-2xl p-6 shadow-sm">
          <div class="space-y-4">
            <div class="flex items-center gap-3">
              <.icon name="hero-document-arrow-up" class="w-6 h-6" />
              <div>
                <p class="text-base font-semibold text-base-content">{gettext("Upload bank CSV")}</p>
                </div>
            </div>

            <.form
              for={@import_form}
              id="import-wizard-upload"
              phx-submit="parse_file"
              phx-change="queue_upload"
            >
              <div class="rounded-2xl border-2 border-dashed border-base-300 bg-base-200/30 p-6 flex flex-col gap-4">
                <label
                  for={@uploads.file.ref}
                  phx-drop-target={@uploads.file.ref}
                  class="cursor-pointer flex flex-col items-center gap-2 text-center"
                >
                  <.icon name="hero-cloud-arrow-up" class="w-12 h-12 text-base-content/50" />
                  <p class="text-base font-medium text-base-content">{gettext("Drag and drop your CSV file")}</p>
                  <p class="text-sm text-base-content/70">{gettext("or click to select (maximum 5MB)")}</p>
                  <.live_file_input upload={@uploads.file} class="sr-only" />
                </label>

                <%= for entry <- @uploads.file.entries do %>
                  <div class="rounded-xl border border-base-300/70 bg-base-100 p-3">
                    <div class="flex justify-between text-sm mb-1">
                      <span>{entry.client_name}</span>
                      <span>{entry.progress}%</span>
                    </div>
                    <progress class="progress progress-primary" value={entry.progress} max="100"></progress>
                  </div>
                <% end %>

                <%= for err <- upload_errors(@uploads.file) do %>
                  <div class="alert alert-error">
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

                <div class="flex justify-end">
                  <.button
                    type="submit"
                    variant="primary"
                    disabled={@uploads.file.entries == []}
                    class="w-full sm:w-auto"
                    phx-disable-with={gettext("Loading...")}
                  >
                    <.icon name="hero-arrow-right" class="w-4 h-4" /> {gettext("Load transactions")}
                  </.button>
                </div>
              </div>
            </.form>
          </div>
        </section>

        <section class="bg-base-100/80 border border-base-300 rounded-2xl p-6 shadow-sm">
          <div class="flex items-center justify-between gap-3 mb-4">
            <div>
              <p class="text-base font-semibold text-base-content">{gettext("Transactions to import")}</p>
              <p class="text-sm text-base-content/70">{gettext("Edit any field, adjust profile/category, and remove lines you do not want to import.")}</p>
            </div>
            <%= if @entries != [] do %>
              <div class="text-sm text-base-content/70">{length(@entries)} {gettext("items")}</div>
            <% end %>
          </div>

          <%= if @entries == [] do %>
            <div class="rounded-xl border border-base-200 bg-base-200/40 p-6 text-sm text-base-content/70">
              {gettext("Upload a CSV in the bank layout shown in your export to see transactions here.")}
            </div>
          <% else %>
            <.form for={%{}} id="entries-form" phx-change="edit_entries" phx-submit="import_entries">
              <div class="overflow-x-auto">
                <table class="table table-zebra w-full">
                  <thead>
                    <tr>
                      <th class="w-10"></th>
                      <th>{gettext("Date")}</th>
                      <th>{gettext("Time")}</th>
                      <th>{gettext("Description")}</th>
                      <th>{gettext("Profile")}</th>
                      <th>{gettext("Category")}</th>
                      <th>{gettext("Type")}</th>
                      <th>{gettext("Quantity")}</th>
                      <th>{gettext("Value")}</th>
                      <th>{gettext("Total")}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for entry <- @entries do %>
                      <tr id={"entry-#{entry.id}"}>
                        <td>
                          <button
                            type="button"
                            class="btn btn-ghost btn-sm text-error"
                            phx-click="remove_entry"
                            phx-value-id={entry.id}
                          >
                            <.icon name="hero-x-mark" class="w-4 h-4" />
                          </button>
                        </td>
                        <td>
                          <input
                            type="date"
                            name={"entries[#{entry.id}][date_input]"}
                            value={date_to_input(entry.date_input)}
                            class="input input-bordered w-full"
                          />
                        </td>
                        <td>
                          <input
                            type="time"
                            name={"entries[#{entry.id}][time_input]"}
                            value={time_to_input(entry.time_input)}
                            class="input input-bordered w-full"
                          />
                        </td>
                        <td>
                          <input
                            type="text"
                            name={"entries[#{entry.id}][description]"}
                            value={entry.description}
                            class="input input-bordered w-full"
                            phx-debounce="300"
                          />
                        </td>
                        <td>
                          <select
                            name={"entries[#{entry.id}][profile_id]"}
                            class="select select-bordered w-full"
                          >
                            <%= for {label, id} <- @profiles_options do %>
                              <option value={id} selected={id == entry.profile_id}>{label}</option>
                            <% end %>
                          </select>
                        </td>
                        <td>
                          <select
                            name={"entries[#{entry.id}][category_id]"}
                            class="select select-bordered w-full"
                          >
                            <%= for {label, id} <- @categories_options do %>
                              <option value={id} selected={id == entry.category_id}>{label}</option>
                            <% end %>
                          </select>
                        </td>
                        <td>
                          <select name={"entries[#{entry.id}][type]"} class="select select-bordered w-full">
                            <option value="income" selected={entry.type == :income}>{gettext("Income")}</option>
                            <option value="expense" selected={entry.type == :expense}>{gettext("Expense")}</option>
                          </select>
                        </td>
                        <td>
                          <input
                            type="number"
                            step="0.00000001"
                            name={"entries[#{entry.id}][amount]"}
                            value={format_float(entry.amount)}
                            class="input input-bordered w-24"
                          />
                        </td>
                        <td>
                          <div class="space-y-1 w-32" phx-update="ignore" id={"value-input-container-#{entry.id}"}>
                            <input
                              id={"value-input-#{entry.id}"}
                              type="text"
                              class="input input-bordered w-full"
                              phx-hook="MoneyInput"
                              data-hidden-name={"entries[#{entry.id}][value]"}
                              value={CurrencyUtils.format_money(entry.value)}
                            />
                            <input
                              type="hidden"
                              name={"entries[#{entry.id}][value]"}
                              value={format_float(entry.value)}
                            />
                          </div>
                        </td>
                        <td class="text-right text-sm font-medium text-base-content">{CurrencyUtils.format_money(entry.total_value)}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <div class="flex justify-end mt-4">
                <.button
                  type="submit"
                  variant="primary"
                  class="w-full sm:w-auto"
                  disabled={@importing}
                  phx-disable-with={gettext("Importing...")}
                >
                  <.icon name="hero-check" class="w-4 h-4" /> {gettext("Import selected")}
                </.button>
              </div>
            </.form>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("parse_file", _params, socket) do
    if socket.assigns.uploads.file.entries == [] do
      {:noreply, put_flash(socket, :error, gettext("Select a CSV file to import."))}
    else
    default_profile_id = socket.assigns.default_profile_id
    default_category_id = socket.assigns.default_category_id

    entries =
      socket
      |> consume_uploaded_entries(:file, fn %{path: path}, _entry ->
        parse_bank_csv(path, default_profile_id, default_category_id)
      end)
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    if entries == [] do
      {:noreply, put_flash(socket, :error, gettext("No transactions found in the file."))}
    else
      {:noreply,
       socket
       |> assign(:entries, entries)
       |> assign(:importing, false)
       |> put_flash(:info, gettext("CSV parsed. Review and import the transactions."))
       |> push_event("scroll-top", %{})}
    end
    end
  end

  @impl true
  def handle_event("queue_upload", _params, socket) do
    # No-op handler just to trigger LV upload consumption lifecycle on change
    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_entries", %{"entries" => entries_params}, socket) do
    {:noreply, assign(socket, :entries, merge_entries(socket.assigns.entries, entries_params))}
  end

  def handle_event("edit_entries", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("remove_entry", %{"id" => id}, socket) do
    {:noreply, assign(socket, :entries, Enum.reject(socket.assigns.entries, &(&1.id == id)))}
  end

  @impl true
  def handle_event("import_entries", params, socket) do
    entries_params = Map.get(params, "entries", %{})
    entries = merge_entries(socket.assigns.entries, entries_params)

    socket = assign(socket, :entries, entries) |> assign(:importing, true)

    results = persist_entries(entries, socket)

    {successes, errors} =
      Enum.split_with(results, fn {_id, result} -> match?({:ok, _}, result) end)

    success_count = length(successes)
    failed_entries_ids = Enum.map(errors, fn {id, _} -> id end)

    failed_entries = Enum.filter(entries, fn entry -> entry.id in failed_entries_ids end)

    socket =
      socket
      |> assign(:entries, failed_entries)
      |> assign(:importing, false)

    cond do
      success_count > 0 and errors == [] ->
        {:noreply,
         socket
         |> put_flash(:info, Gettext.ngettext(PersonalFinanceWeb.Gettext, "%{count} transaction imported.", "%{count} transactions imported.", success_count, count: success_count))
         |> push_navigate(to: ~p"/ledgers/#{socket.assigns.ledger.id}/transactions")}

      success_count > 0 and errors != [] ->
        {:noreply,
         socket
         |> put_flash(:info, Gettext.ngettext(PersonalFinanceWeb.Gettext, "%{count} transaction imported.", "%{count} transactions imported.", success_count, count: success_count))
         |> put_flash(:error, gettext("Some rows failed to import. Please review the remaining items."))}

      errors != [] ->
        {:noreply, socket |> put_flash(:error, gettext("No transactions were imported. Please review the entries."))}
    end
  end

  defp parse_bank_csv(path, default_profile_id, default_category_id) do
    path
    |> File.stream!()
    |> Enum.drop_while(fn line -> String.trim_leading(line) |> String.starts_with?("INITIAL_BALANCE") end)
    |> Enum.drop_while(fn line -> not String.starts_with?(String.trim_leading(line), "RELEASE_DATE") end)
    |> Enum.reject(&(String.trim(&1) == ""))
    |> CSV.decode!(separator: ?;, headers: true)
    |> Enum.map(&row_to_entry(&1, default_profile_id, default_category_id))
    |> Enum.reject(&is_nil/1)
  end

  defp row_to_entry(row, default_profile_id, default_category_id) do
    date =
      case ParseUtils.parse_date_safe(row["RELEASE_DATE"]) do
        {:ok, parsed} -> parsed
        _ -> nil
      end

    if is_nil(date) do
      nil
    else
      value = ParseUtils.parse_float_locale(row["TRANSACTION_NET_AMOUNT"])
      type = if value < 0, do: :expense, else: :income
      value = abs(value) |> Float.round(2)
      amount = 1.0

      %{
        id: UUID.generate(),
        description: row["TRANSACTION_TYPE"] |> (fn val -> val || "" end).() |> String.trim(),
        value: value,
        amount: amount,
        total_value: Float.round(value * amount, 2),
        date_input: date,
        time_input: current_time_local(),
        type: type,
        profile_id: default_profile_id,
        category_id: default_category_id
      }
    end
  end

  defp merge_entries(entries, params) do
    Enum.map(entries, fn entry ->
      row_params = Map.get(params, entry.id, %{})
      update_entry(entry, row_params)
    end)
  end

  defp update_entry(entry, params) do
    value = params |> Map.get("value", entry.value) |> ParseUtils.parse_float_locale()
    amount = params |> Map.get("amount", entry.amount) |> parse_amount()
    type = params |> Map.get("type", entry.type) |> parse_type()
    profile_id = params |> Map.get("profile_id", entry.profile_id) |> ParseUtils.parse_id()
    category_id = params |> Map.get("category_id", entry.category_id) |> ParseUtils.parse_id()

    %{
      entry
      | description: params |> Map.get("description", entry.description) |> default_description(),
        date_input: params |> Map.get("date_input", entry.date_input) |> parse_date_input(entry.date_input),
        time_input: params |> Map.get("time_input", entry.time_input) |> parse_time_input(entry.time_input),
        value: value |> abs() |> Float.round(2),
        amount: amount,
        total_value: Float.round(abs(value) * amount, 2),
        type: type,
        profile_id: profile_id || entry.profile_id,
        category_id: category_id || entry.category_id
    }
  end

  defp parse_amount(val) do
    case ParseUtils.parse_float_locale(val) do
      num when num <= 0 -> 1.0
      num -> num
    end
  end

  defp parse_type(val) when val in ["income", :income], do: :income
  defp parse_type(val) when val in ["expense", :expense], do: :expense
  defp parse_type(_), do: :expense

  defp parse_date_input(%Date{} = date, _fallback), do: date

  defp parse_date_input(value, fallback) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> fallback
    end
  end

  defp parse_date_input(_, fallback), do: fallback

  defp parse_time_input(%Time{} = time, _fallback), do: truncate_time(time)

  defp parse_time_input(value, fallback) when is_binary(value) do
    normalized =
      case String.split(value, ":") do
        [h, m] -> "#{h}:#{m}:00"
        [h, m, s] -> "#{h}:#{m}:#{s}"
        _ -> value
      end

    case Time.from_iso8601(normalized) do
      {:ok, time} -> truncate_time(time)
      _ -> fallback
    end
  end

  defp parse_time_input(_, fallback), do: fallback

  defp truncate_time(%Time{} = time) do
    %Time{time | second: 0, microsecond: {0, 0}}
  end

  defp default_description(nil), do: ""
  defp default_description(desc) when is_binary(desc), do: String.trim(desc)
  defp default_description(other), do: to_string(other)

  defp persist_entries(entries, socket) do
    Enum.map(entries, fn entry ->
      attrs = entry_to_attrs(entry, socket)
      {entry.id, Finance.create_transaction(socket.assigns.current_scope, attrs, socket.assigns.ledger)}
    end)
  end

  defp entry_to_attrs(entry, socket) do
    value = entry.value |> ParseUtils.parse_float_locale() |> abs() |> Float.round(2)
    amount = entry.amount |> parse_amount()
    total_value = Float.round(value * amount, 2)

    %{
      "description" => default_description(entry.description) |> fallback_description(),
      "value" => value,
      "amount" => amount,
      "total_value" => total_value,
      "date_input" => entry.date_input || Date.utc_today(),
      "time_input" => entry.time_input || current_time_local(),
      "category_id" => entry.category_id || socket.assigns.default_category_id,
      "profile_id" => entry.profile_id || socket.assigns.default_profile_id,
      "type" => parse_type(entry.type)
    }
  end

  defp fallback_description(""), do: gettext("No description")
  defp fallback_description(desc), do: desc

  defp format_float(val) when is_number(val) do
    :erlang.float_to_binary(val * 1.0, [:compact, {:decimals, 8}]) |> String.trim_trailing(".0")
  end

  defp format_float(val) when is_binary(val), do: val
  defp format_float(_), do: ""

  defp date_to_input(%Date{} = date), do: Date.to_iso8601(date)
  defp date_to_input(_), do: ""

  defp time_to_input(%Time{} = time) do
    time |> Time.truncate(:second) |> Time.to_iso8601() |> String.slice(0, 5)
  end

  defp time_to_input(_) do
    current_time_local() |> Time.truncate(:second) |> Time.to_iso8601() |> String.slice(0, 5)
  end

  defp current_time_local do
    DateTime.utc_now() |> DateUtils.to_local_time_with_date() |> NaiveDateTime.to_time() |> truncate_time()
  end
end
