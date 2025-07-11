defmodule PersonalFinance.Finance do
  alias PersonalFinance.Finance.BudgetsUsers
  alias PersonalFinance.Finance.BudgetInvite
  alias PersonalFinance.Repo
  alias PersonalFinance.Accounts.Scope

  alias PersonalFinance.Finance.{
    Transaction,
    Category,
    InvestmentType,
    Profile,
    Budget,
    RecurringEntry
  }

  import Ecto.Query

  @doc """
  Retorna tipos de investimento.
  """
  def list_investment_types do
    InvestmentType
    |> Repo.all()
  end

  @doc """
  Returns the list of categories for a budget.
  """
  def list_categories(%Scope{} = scope, %Budget{} = budget) do
    Category
    |> where([c], c.budget_id == ^budget.id)
    |> Repo.all()
  end

  @doc """
  Create a category changeset for a budget and user.
  """
  def change_category(
        %Scope{} = scope,
        %Category{} = category,
        %Budget{} = budget,
        attrs \\ %{}
      ) do
    Category.changeset(category, attrs, budget.id)
  end

  @doc """
  Returns a category by ID.
  """
  def get_category(%Scope{} = scope, id, %Budget{} = budget) do
    Category
    |> Repo.get(id)
    |> Repo.preload(:budget)
  end

  @doc """
  Returns a category by name for a budget.
  """
  def get_category_by_name(name, %Scope{} = scope, budget) do
    Category
    |> where([c], c.name == ^name and c.budget_id == ^budget.id)
    |> Repo.one()
  end

  @doc """
  Returns the total value of transactions for a specific category.
  """
  def get_total_value_by_category(category_id, transactions) do
    transactions
    |> Enum.filter(fn t -> t.category_id == category_id end)
    |> Enum.reduce(0, fn t, acc -> acc + t.total_value end)
  end

  @doc """
  Creates a category.
  """
  def create_category(%Scope{} = scope, attrs, budget) do
    with {:ok, category = %Category{}} <-
           %Category{}
           |> Category.changeset(attrs, budget.id)
           |> Repo.insert() do
      fully_loaded_category =
        category
        |> Repo.preload(:budget)

      broadcast(:category, budget.id, {:saved, fully_loaded_category})
      {:ok, fully_loaded_category}
    else
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a category.
  """
  def update_category(%Scope{} = scope, %Category{} = category, attrs) do
    changeset = category |> Category.changeset(attrs, category.budget.id)

    case Repo.update(changeset) do
      {:ok, updated_category} ->
        fully_loaded_category =
          Category |> Repo.get!(updated_category.id) |> Repo.preload([:budget])

        broadcast(:category, updated_category.budget_id, {:saved, fully_loaded_category})

        {:ok, fully_loaded_category}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a category and resets transactions to default category.
  """
  def delete_category(%Scope{} = scope, %Category{} = category) do
    if category.is_default || category.is_fixed do
      {:error, "Cannot delete default/fixed category"}
    else
      default_category =
        Category
        |> where([c], c.is_default == true and c.budget_id == ^category.budget_id)
        |> Repo.one()

      from(t in Transaction,
        where: t.category_id == ^category.id and t.budget_id == ^category.budget_id
      )
      |> Repo.update_all(set: [category_id: default_category.id])

      broadcast(:transaction, category.budget_id, :transactions_updated)

      with {:ok, deleted_category} <- Repo.delete(category) do
        broadcast(:category, category.budget_id, {:deleted, deleted_category})
        {:ok, deleted_category}
      else
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Create a transaction changeset for a budget and user.
  """
  def change_transaction(
        %Scope{} = scope,
        %Transaction{} = transaction,
        %Budget{} = budget,
        attrs \\ %{}
      ) do
    Transaction.changeset(transaction, attrs, budget.id)
  end

  @doc """
  Retorna transação por ID.
  """
  def get_transaction(%Scope{} = scope, id, %Budget{} = budget) do
    Transaction
    |> Repo.get_by(id: id, budget_id: budget.id)
    |> Repo.preload([:budget, :category, :investment_type, :profile])
  end

  @doc """
  Retorna a lista de transações para um orçamento
  """
  def list_transactions(%Scope{} = scope, budget) do
    from(t in Transaction,
      order_by: [desc: t.date],
      where: t.budget_id == ^budget.id
    )
    |> Ecto.Query.preload([:category, :investment_type, :profile])
    |> Repo.all()
  end

  @doc """
  Cria uma transação.
  """
  def create_transaction(%Scope{} = scope, attrs, %Budget{} = budget) do
    attrs =
      if Map.get(attrs, "category_id") do
        attrs
      else
        default_category =
          Category
          |> where([c], c.is_default == true and c.budget_id == ^budget.id)
          |> Repo.one()

        Map.put(attrs, "category_id", default_category.id)
      end

    changeset =
      %Transaction{}
      |> Transaction.changeset(attrs, budget.id)

    IO.inspect(changeset, label: "Transaction Changeset")

    case Repo.insert(changeset) do
      {:ok, new_transaction} ->
        new_transaction =
          new_transaction
          |> Repo.preload([:category, :investment_type, :profile])

        broadcast(:transaction, budget.id, {:saved, new_transaction})
        {:ok, new_transaction}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Atualiza uma transação.
  """
  def update_transaction(%Scope{} = scope, %Transaction{} = transaction, attrs) do
    changeset =
      transaction
      |> Transaction.changeset(attrs, transaction.budget.id)

    case Repo.update(changeset) do
      {:ok, updated_transaction} ->
        fully_loaded_transaction =
          Transaction
          |> Repo.get!(updated_transaction.id)
          |> Repo.preload([:category, :investment_type, :profile])

        broadcast(:transaction, updated_transaction.budget_id, {:saved, fully_loaded_transaction})

        {:ok, fully_loaded_transaction}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deleta uma transação.
  """
  def delete_transaction(%Scope{} = scope, %Transaction{} = transaction) do
    with {:ok, deleted_transaction} <- Repo.delete(transaction) do
      broadcast(:transaction, transaction.budget_id, {:deleted, deleted_transaction})
      {:ok, deleted_transaction}
    else
      {:error, _} = error -> error
    end
  end

  @doc """
  Create a budget changeset for a user.
  """
  def change_budget(%Scope{} = scope, %Budget{} = budget, attrs \\ %{}) do
    Budget.changeset(budget, attrs, scope.user.id)
  end

  @doc """
  Returns all budgets for a user.
  """
  def list_budgets(%Scope{} = scope) do
    from(b in PersonalFinance.Finance.Budget,
      # Inclui orçamentos onde o usuário é o proprietário
      where: b.owner_id == ^scope.user.id,
      # OU
      or_where:
        b.id in subquery(
          # Nome da sua tabela de associação
          from(bu in "budgets_users",
            where: bu.user_id == ^scope.user.id,
            select: bu.budget_id
          )
        ),
      # Garante que cada orçamento apareça apenas uma vez
      distinct: true
    )
    # Mantém o preload do proprietário
    |> Ecto.Query.preload(:owner)
    |> Repo.all()
  end

  @doc """
  Get budget users including the owner.
  """
  def list_budget_users(%Scope{} = scope, %Budget{} = budget) do
    from(bu in BudgetsUsers,
      where: bu.budget_id == ^budget.id,
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.map(fn bu -> bu.user end)
    |> Enum.uniq()
    |> Enum.concat([budget.owner])
    |> Enum.sort_by(& &1.email)
  end

  @doc """
  Get budget invites.
  """
  def list_budget_invites(%Scope{} = scope, %Budget{} = budget, status) do
    from(bi in BudgetInvite,
      where: bi.budget_id == ^budget.id,
      where: bi.status == ^status,
      preload: [:inviter, :invited_user]
    )
    |> Repo.all()
  end

  @doc """
  Updates a budget.
  """
  def update_budget(%Scope{} = scope, %Budget{} = budget, attrs) do
    with {:ok, budget = %Budget{}} <-
           budget
           |> Budget.changeset(attrs, scope.user.id)
           |> Repo.update() do
      {:ok, Repo.preload(budget, [:owner])}
    end
  end

  @doc """
  Deletes a budget.
  """
  def delete_budget(%Scope{} = scope, %Budget{} = budget) do
    Repo.delete(budget)
  end

  @doc """
  Returns a budget by ID for a user.
  """
  def get_budget(%Scope{} = scope, id) do
    from(b in PersonalFinance.Finance.Budget,
      preload: [:owner],
      where:
        b.id == ^id and
          (b.owner_id == ^scope.user.id or
             b.id in subquery(
               from(bu in "budgets_users",
                 where: bu.user_id == ^scope.user.id,
                 select: bu.budget_id
               )
             ))
    )
    |> PersonalFinance.Repo.one()
  end

  @doc """
  Creates a budget.
  """
  def create_budget(%Scope{} = scope, attrs) do
    changeset =
      %Budget{}
      |> Budget.changeset(attrs, scope.user.id)

    case Repo.insert(changeset) do
      {:ok, new_budget} ->
        {:ok, Repo.preload(new_budget, [:owner])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Remove a user from a budget.
  """
  def remove_budget_user(%Scope{} = scope, %Budget{} = budget, user_id) do
    if budget.owner_id != scope.user.id do
      {:error, "You are not the owner of this budget."}
    else
      from(bu in BudgetsUsers,
        where: bu.budget_id == ^budget.id and bu.user_id == ^user_id
      )
      |> Repo.delete_all()

      from(bi in BudgetInvite,
        where: bi.budget_id == ^budget.id and bi.invited_user_id == ^user_id
      )
      |> Repo.delete_all()

      {:ok, "User removed from budget."}
    end
  end

  @doc """
  Creates default profiles for a budget.
  """
  def create_default_profiles(%Scope{} = scope, %Budget{} = budget) do
    default_profile_attrs = %{
      "name" => "Eu",
      "description" => "Perfil principal do usuário",
      "is_default" => true,
      "budget_id" => budget.id
    }

    create_profile(scope, default_profile_attrs, budget)
  end

  @doc """
  Creates default categories for a budget.
  """
  def create_default_categories(%Scope{} = scope, %Budget{} = budget) do
    default_categories_attrs = [
      %{
        "name" => "Sem Categoria",
        "description" => "Transações sem categoria",
        "is_default" => true,
        "is_fixed" => true
      },
      %{
        "name" => "Investimento",
        "description" => "Transações de investimento",
        "is_default" => false,
        "is_fixed" => true
      }
    ]

    results =
      Enum.map(default_categories_attrs, fn category_attrs_map ->
        create_category(scope, category_attrs_map, budget)
      end)

    failed_results =
      Enum.filter(results, fn
        {:ok, _} -> false
        {:error, _} -> true
      end)

    if Enum.empty?(failed_results) do
      {:ok, "Default categories created successfully."}
    else
      {:error, failed_results}
    end
  end

  @doc """
  Create a profile changeset for a budget and user.
  """
  def change_profile(
        %Scope{} = scope,
        %Profile{} = profile,
        %Budget{} = budget,
        attrs \\ %{}
      ) do
    Profile.changeset(profile, attrs, budget.id)
  end

  @doc """
  Returns a list of profiles for a budget.
  """
  def list_profiles(%Scope{} = scope, budget) do
    Profile
    |> where([p], p.budget_id == ^budget.id)
    |> Repo.all()
  end

  @doc """
  Return a profile by ID for a budget.
  """
  def get_profile(%Scope{} = scope, budget_id, id) do
    budget = get_budget(scope, budget_id)

    if budget == nil do
      nil
    else
      Profile
      |> Ecto.Query.preload(:budget)
      |> Repo.get_by(id: id, budget_id: budget.id)
    end
  end

  @doc """
  Updates a profile.
  """
  def update_profile(%Scope{} = scope, %Profile{} = profile, attrs) do
    with {:ok, updated_profile = %Profile{}} <-
           profile
           |> Profile.changeset(attrs, profile.budget.id)
           |> Repo.update() do
      broadcast(:profile, updated_profile.budget_id, {:saved, updated_profile})
      {:ok, updated_profile}
    else
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Creates a profile for a budget.
  """
  def create_profile(%Scope{} = scope, attrs, budget) do
    with {:ok, profile = %Profile{}} <-
           %Profile{}
           |> Profile.changeset(attrs, budget.id)
           |> Repo.insert() do
      broadcast(:profile, budget.id, {:saved, profile})
      {:ok, profile}
    else
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a profile and resets transactions to default profile.
  """
  def delete_profile(%Scope{} = scope, %Profile{} = profile) do
    if profile.is_default do
      {:error, "Cannot delete default profile"}
    else
      default_profile =
        Profile
        |> where([p], p.is_default == true and p.budget_id == ^profile.budget_id)
        |> Repo.one()

      from(t in Transaction,
        where: t.profile_id == ^profile.id and t.budget_id == ^profile.budget_id
      )
      |> Repo.update_all(set: [profile_id: default_profile.id])

      broadcast(:transaction, profile.budget_id, :transactions_updated)

      with {:ok, deleted_profile} <- Repo.delete(profile) do
        broadcast(:profile, profile.budget_id, {:deleted, deleted_profile})
        {:ok, deleted_profile}
      else
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Create a budget invite
  """
  def create_budget_invite(%Scope{} = scope, budget, email) do
    if budget.owner_id != scope.user.id do
      {:error, "You are not the owner of this budget."}
    else
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64()
      expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(7 * 24 * 60 * 60, :second)

      attrs = %{
        budget_id: budget.id,
        email: email,
        token: token,
        inviter_id: scope.user.id,
        status: :pending,
        expires_at: expires_at
      }

      %BudgetInvite{}
      |> BudgetInvite.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Get a budget invite by token
  """
  def get_budget_invite_by_token(token) do
    Repo.get_by(BudgetInvite, token: token) |> Repo.preload([:budget, :inviter, :invited_user])
  end

  @doc """
  Accept a budget invite
  """
  def accept_budget_invite(user, %BudgetInvite{} = invite) do
    if invite.status == :pending && user.email == invite.email &&
         (is_nil(invite.expires_at) ||
            NaiveDateTime.compare(NaiveDateTime.utc_now(), invite.expires_at) == :lt) do
      Repo.transaction(fn ->
        invite =
          invite
          |> BudgetInvite.changeset(%{status: :accepted, invited_user_id: user.id})
          |> Repo.update!()

        %BudgetsUsers{}
        |> BudgetsUsers.changeset(%{
          budget_id: invite.budget_id,
          user_id: user.id
        })
        |> Repo.insert!()

        {:ok, invite}
      end)
    else
      {:error, "Invite is not valid or has expired."}
    end
  end

  @doc """
  Decline a budget invite
  """
  def decline_budget_invite(user, %BudgetInvite{} = invite) do
    if invite.status == :pending && user.email == invite.email &&
         (is_nil(invite.expires_at) ||
            NaiveDateTime.compare(NaiveDateTime.utc_now(), invite.expires_at) == :lt) do
      invite
      |> BudgetInvite.changeset(%{status: :declined})
      |> Repo.update()
    else
      {:error, "Invite is not valid or has expired."}
    end
  end

  @doc """
  Revoke a budget invite
  """
  def revoke_budget_invite(%Scope{} = scope, %Budget{} = budget, invite_id) do
    if budget.owner_id != scope.user.id do
      {:error, "You are not the owner of this budget."}
    else
      invite =
        BudgetInvite
        |> where([bi], bi.id == ^invite_id and bi.budget_id == ^budget.id)
        |> Repo.one()

      if invite do
        Repo.delete(invite)
      else
        {:error, "Invite not found."}
      end
    end
  end

  @doc """
  Create a recurring entry changeset for a budget and user.
  """
  def change_recurring_entry(
        %Scope{} = scope,
        %PersonalFinance.Finance.RecurringEntry{} = recurring_entry,
        %Budget{} = budget,
        attrs \\ %{}
      ) do
    RecurringEntry.changeset(recurring_entry, attrs, budget.id)
  end

  @doc """
  Create a recurring entry.
  """
  def create_recurring_entry(%Scope{} = scope, attrs, %Budget{} = budget) do
    with {:ok, recurring_entry = %RecurringEntry{}} <-
           %RecurringEntry{}
           |> RecurringEntry.changeset(attrs, budget.id)
           |> Repo.insert() do
      broadcast(:recurring_entry, budget.id, {:saved, recurring_entry})
      {:ok, recurring_entry}
    else
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a recurring entry.
  """
  def update_recurring_entry(%Scope{} = scope, %RecurringEntry{} = recurring_entry, attrs) do
    changeset =
      recurring_entry
      |> RecurringEntry.changeset(attrs, recurring_entry.budget.id)

    case Repo.update(changeset) do
      {:ok, updated_recurring_entry} ->
        broadcast(
          :recurring_entry,
          updated_recurring_entry.budget_id,
          {:saved, updated_recurring_entry}
        )

        {:ok, updated_recurring_entry}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a recurring entry.
  """
  def delete_recurring_entry(%Scope{} = scope, %RecurringEntry{} = recurring_entry) do
    with {:ok, deleted_recurring_entry} <- Repo.delete(recurring_entry) do
      broadcast(:recurring_entry, recurring_entry.budget.id, {:deleted, deleted_recurring_entry})
      {:ok, deleted_recurring_entry}
    else
      {:error, _} = error -> error
    end
  end

  @doc """
  List recurring entries for a budget and profile
  """
  def list_recurring_entries(%Scope{} = scope, budget_id, profile_id) do
    from(re in RecurringEntry,
      where: re.budget_id == ^budget_id and re.profile_id == ^profile_id,
      order_by: [asc: re.start_date]
    )
    |> Repo.all()
  end

  @doc """
  Get a recurring entry by ID for a budget and profile.
  """
  def get_recurring_entry(%Scope{} = scope, budget_id, id) do
    from(re in RecurringEntry,
      where: re.budget_id == ^budget_id and re.id == ^id
    )
    |> Repo.one()
    |> Repo.preload([:budget, :category, :profile])
  end

  @doc """
  Toggle the status of a recurring entry.
  """
  def toggle_recurring_entry_status(%Scope{} = scope, %RecurringEntry{} = recurring_entry) do
    new_status = not recurring_entry.is_active

    changeset =
      recurring_entry
      |> RecurringEntry.changeset(%{is_active: new_status}, recurring_entry.budget.id)

    case Repo.update(changeset) do
      {:ok, updated_recurring_entry} ->
        broadcast(
          :recurring_entry,
          updated_recurring_entry.budget_id,
          {:saved, updated_recurring_entry}
        )

        {:ok, updated_recurring_entry}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  List the pending recurrent transactions for a budget.
  """
  def list_pending_recurrent_transactions(%Scope{} = scope, budget_id) do
    recurring_entries =
      from(re in RecurringEntry,
        where:
          re.budget_id == ^budget_id and re.is_active == true and
            re.start_date <= ^Date.utc_today(),
        order_by: [asc: re.start_date, asc: re.description],
        preload: [:category, :profile]
      )
      |> Repo.all()

    today = Date.utc_today()
    current_month_start = Date.beginning_of_month(today)

    generated_transactions_in_period =
      from(t in Transaction,
        where:
          t.budget_id == ^budget_id and t.date >= ^current_month_start and
            not is_nil(t.recurring_entry_id),
        select: t.recurring_entry_id
      )
      |> Repo.all()
      |> MapSet.new()

    Enum.flat_map(recurring_entries, fn %RecurringEntry{} = entry ->
      date_expected =
        case entry.frequency do
          :daily -> Date.add(entry.start_date, 1)
          :weekly -> Date.add(entry.start_date, 7)
          :monthly -> Date.add(entry.start_date, Date.days_in_month(today))
          :yearly -> Date.add(entry.start_date, 365)
        end

      is_pending =
        date_expected &&
          (is_nil(entry.end_date) || Date.compare(date_expected, entry.end_date) == :lt) &&
          not MapSet.member?(generated_transactions_in_period, entry.id) &&
          Date.compare(date_expected, Date.add(today, 60)) == :lt

      if is_pending do
        [
          %{
            id: entry.id,
            description: entry.description,
            amount: entry.amount,
            value: entry.value,
            date_expected: date_expected,
            recurring_entry: entry
          }
        ]
      else
        []
      end
    end)
  end

  @doc """
  Generate a transaction from a recurring entry.
  """
  def confirm_recurring_transaction(
        %Scope{} = scope,
        %Budget{} = budget,
        id
      ) do
    if budget do
      recurring_entry = get_recurring_entry(scope, budget.id, id)

      transaction_attrs = %{
        "description" => recurring_entry.description,
        "value" => recurring_entry.value,
        "amount" => recurring_entry.amount,
        "date" => Date.utc_today(),
        "category_id" => recurring_entry.category_id,
        "profile_id" => recurring_entry.profile_id,
        "budget_id" => budget.id,
        "recurring_entry_id" => recurring_entry.id
      }

      create_transaction(scope, transaction_attrs, budget)
    else
      {:error, "Budget not found."}
    end
  end

  @doc """
  Subscribes to scoped notifications abour any finance related changes.

  The broadcasted message match the pattern
  * {:saved, %Resource{}}
  * {:deleted, %Resource{}}
  """
  def subscribe_finance(resource, budget_id) do
    IO.inspect(
      "Subscribing to finance notifications for resource: #{resource} and budget_id: #{budget_id}"
    )

    Phoenix.PubSub.subscribe(PersonalFinance.PubSub, "finance:#{budget_id}:#{resource}")
  end

  defp broadcast(resource, budget_id, message) do
    IO.inspect(
      "Broadcasting finance notification for resource: #{resource}, budget_id: #{budget_id}"
    )

    Phoenix.PubSub.broadcast(
      PersonalFinance.PubSub,
      "finance:#{budget_id}:#{resource}",
      message
    )
  end
end
