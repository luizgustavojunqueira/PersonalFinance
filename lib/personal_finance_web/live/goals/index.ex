defmodule PersonalFinanceWeb.GoalsLive.Index do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance
  alias PersonalFinance.Goals
  alias PersonalFinance.Goals.Goal
  alias PersonalFinance.Investment
  alias PersonalFinance.Utils.{ParseUtils, CurrencyUtils}

  @impl true
  def mount(params, _session, socket) do
    current_scope = socket.assigns.current_scope
    ledger = Finance.get_ledger(current_scope, params["id"])

    if ledger == nil do
      {:ok,
       socket
       |> put_flash(:error, gettext("Ledger not found."))
       |> push_navigate(to: ~p"/ledgers")}
    else
      goals = Goals.list_goals(current_scope, ledger.id)
      profiles = Finance.list_profiles(current_scope, ledger)
      fixed_incomes = Investment.list_fixed_incomes(ledger)
      available_ids = Goals.available_fixed_income_ids(nil, ledger.id)

      {:ok,
       socket
       |> assign(
         page_title: gettext("Goals"),
         ledger: ledger,
         goals: goals,
         profiles: profiles,
         fixed_incomes: fixed_incomes,
         available_fixed_income_ids: available_ids,
         open_modal: nil,
         current_goal: nil,
         selected_fixed_income_ids: [],
         form: to_form(Goal.changeset(%Goal{}, %{}), as: :goal)
       )}
    end
  end

  @impl true
  def handle_event("open_modal", %{"modal" => modal}, socket) do
    modal_atom = String.to_existing_atom(modal)

    available_ids = Goals.available_fixed_income_ids(nil, socket.assigns.ledger.id)

    {:noreply,
     socket
     |> assign(
       open_modal: modal_atom,
       current_goal: nil,
       selected_fixed_income_ids: [],
       available_fixed_income_ids: available_ids
     )
     |> assign(form: to_form(Goal.changeset(%Goal{}, %{}), as: :goal))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, open_modal: nil, current_goal: nil)}
  end

  def handle_event("edit_goal", %{"id" => id}, socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope

    goal = Goals.get_goal!(current_scope, id, ledger.id, preload: [:fixed_incomes, :profile])
    selected_fixed_income_ids = Enum.map(goal.fixed_incomes, & &1.id)
    available_ids = Goals.available_fixed_income_ids(goal.id, ledger.id)

    formatted_amount =
      if goal.target_amount do
        goal.target_amount
        |> Decimal.to_float()
        |> CurrencyUtils.format_money()
      else
        ""
      end

    {:noreply,
     socket
     |> assign(
       open_modal: :edit_goal,
       current_goal: goal,
       selected_fixed_income_ids: selected_fixed_income_ids,
       available_fixed_income_ids: available_ids,
       form: to_form(Goal.changeset(goal, %{}), as: :goal)
     )
     |> push_event("seed-money-input", %{id: "goal_target_amount_input", value: formatted_amount})}
  end

  def handle_event("validate", %{"goal" => params}, socket) do
    changeset =
      socket.assigns.current_goal
      |> Kernel.||(% Goal{})
      |> Goal.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :goal))}
  end

  def handle_event("toggle_fi_selection", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    current = socket.assigns.selected_fixed_income_ids

    new_selection =
      if id in current do
        List.delete(current, id)
      else
        [id | current]
      end

    {:noreply, assign(socket, selected_fixed_income_ids: new_selection)}
  end

  def handle_event("save", %{"goal" => params}, socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope
    selected_ids = parse_fixed_income_ids(params)

    attrs = build_attrs(params)

    result =
      case socket.assigns.current_goal do
        %Goal{} = goal -> Goals.update_goal(goal, attrs)
        _ -> Goals.create_goal(current_scope, attrs, ledger.id)
      end

    case result do
      {:ok, goal} ->
        case Goals.sync_fixed_incomes(goal, selected_ids) do
          {:ok, _updated_goal} ->
            goals = Goals.list_goals(current_scope, ledger.id)
            available_ids = Goals.available_fixed_income_ids(nil, ledger.id)

            {:noreply,
             socket
             |> assign(
               goals: goals,
               open_modal: nil,
               current_goal: nil,
               selected_fixed_income_ids: [],
               available_fixed_income_ids: available_ids,
               form: to_form(Goal.changeset(%Goal{}, %{}), as: :goal)
             )
             |> put_flash(:info, gettext("Goal saved."))}

          {:error, :invalid_fixed_income_selection} ->
            {:noreply,
             socket
             |> put_flash(:error, gettext("Some fixed incomes are already linked to another goal."))}

          {:error, reason} ->
            {:noreply, socket |> put_flash(:error, inspect(reason))}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :goal))}
    end
  end

  def handle_event("delete_goal", %{"id" => id}, socket) do
    ledger = socket.assigns.ledger
    current_scope = socket.assigns.current_scope

    goal = Goals.get_goal!(current_scope, id, ledger.id)
    {:ok, _} = Goals.delete_goal(goal)

    goals = Goals.list_goals(current_scope, ledger.id)

    {:noreply, assign(socket, goals: goals, open_modal: nil)}
  end

  defp parse_fixed_income_ids(params) do
    params
    |> Map.get("fixed_income_ids", [])
    |> List.wrap()
    |> Enum.map(&ParseUtils.parse_id/1)
    |> Enum.reject(&is_nil/1)
  end

  defp build_attrs(params) do
    target_amount =
      params
      |> Map.get("target_amount", "0")
      |> ParseUtils.parse_float_locale()
      |> Decimal.from_float()

    target_date =
      params
      |> Map.get("target_date")
      |> case do
        nil -> nil
        "" -> nil
        date_str ->
          case Date.from_iso8601(date_str) do
            {:ok, date} -> date
            _ -> nil
          end
      end

    profile_id = ParseUtils.parse_id(Map.get(params, "profile_id"))

    %{
      name: params["name"],
      description: params["description"],
      target_amount: target_amount,
      target_date: target_date,
      color: Map.get(params, "color", "#2563eb"),
      profile_id: profile_id
    }
  end
end
