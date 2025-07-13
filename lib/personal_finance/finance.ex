defmodule PersonalFinance.Finance do
  alias PersonalFinance.Finance.LedgersUsers
  alias PersonalFinance.Finance.LedgerInvite
  alias PersonalFinance.Repo
  alias PersonalFinance.Accounts.Scope

  alias PersonalFinance.Finance.{
    Transaction,
    Category,
    InvestmentType,
    Profile,
    Ledger,
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
  Returns the list of categories for a ledger.
  """
  def list_categories(%Scope{} = scope, %Ledger{} = ledger) do
    Category
    |> where([c], c.ledger_id == ^ledger.id)
    |> Repo.all()
  end

  @doc """
  Create a category changeset for a ledger and user.
  """
  def change_category(
        %Scope{} = scope,
        %Category{} = category,
        %Ledger{} = ledger,
        attrs \\ %{}
      ) do
    Category.changeset(category, attrs, ledger.id)
  end

  @doc """
  Returns a category by ID.
  """
  def get_category(%Scope{} = scope, id, %Ledger{} = ledger) do
    Category
    |> Repo.get(id)
    |> Repo.preload(:ledger)
  end

  @doc """
  Returns a category by name for a ledger.
  """
  def get_category_by_name(name, %Scope{} = scope, ledger) do
    Category
    |> where([c], c.name == ^name and c.ledger_id == ^ledger.id)
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
  def create_category(%Scope{} = scope, attrs, ledger) do
    with {:ok, category = %Category{}} <-
           %Category{}
           |> Category.changeset(attrs, ledger.id)
           |> Repo.insert() do
      fully_loaded_category =
        category
        |> Repo.preload(:ledger)

      broadcast(:category, ledger.id, {:saved, fully_loaded_category})
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
    changeset = category |> Category.changeset(attrs, category.ledger.id)

    case Repo.update(changeset) do
      {:ok, updated_category} ->
        fully_loaded_category =
          Category |> Repo.get!(updated_category.id) |> Repo.preload([:ledger])

        broadcast(:category, updated_category.ledger_id, {:saved, fully_loaded_category})

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
        |> where([c], c.is_default == true and c.ledger_id == ^category.ledger_id)
        |> Repo.one()

      from(t in Transaction,
        where: t.category_id == ^category.id and t.ledger_id == ^category.ledger_id
      )
      |> Repo.update_all(set: [category_id: default_category.id])

      broadcast(:transaction, category.ledger_id, :transactions_updated)

      with {:ok, deleted_category} <- Repo.delete(category) do
        broadcast(:category, category.ledger_id, {:deleted, deleted_category})
        {:ok, deleted_category}
      else
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Create a transaction changeset for a ledger and user.
  """
  def change_transaction(
        %Scope{} = scope,
        %Transaction{} = transaction,
        %Ledger{} = ledger,
        attrs \\ %{}
      ) do
    Transaction.changeset(transaction, attrs, ledger.id)
  end

  @doc """
  Retorna transação por ID.
  """
  def get_transaction(%Scope{} = scope, id, %Ledger{} = ledger) do
    Transaction
    |> Repo.get_by(id: id, ledger_id: ledger.id)
    |> Repo.preload([:ledger, :category, :investment_type, :profile])
  end

  @doc """
  Retorna a lista de transações para um orçamento
  """
  def list_transactions(%Scope{} = scope, ledger, profile_id \\ nil) do
    query =
      from(t in Transaction,
        order_by: [desc: t.date],
        where: t.ledger_id == ^ledger.id
      )

    query =
      if profile_id do
        from(t in query, where: t.profile_id == ^profile_id)
      else
        query
      end

    query
    |> Ecto.Query.preload([:category, :investment_type, :profile])
    |> Repo.all()
  end

  @doc """
  Cria uma transação.
  """
  def create_transaction(%Scope{} = scope, attrs, %Ledger{} = ledger) do
    attrs =
      if Map.get(attrs, "category_id") do
        attrs
      else
        default_category =
          Category
          |> where([c], c.is_default == true and c.ledger_id == ^ledger.id)
          |> Repo.one()

        Map.put(attrs, "category_id", default_category.id)
      end

    changeset =
      %Transaction{}
      |> Transaction.changeset(attrs, ledger.id)

    case Repo.insert(changeset) do
      {:ok, new_transaction} ->
        new_transaction =
          new_transaction
          |> Repo.preload([:category, :investment_type, :profile])

        Ledger
        |> Repo.get!(ledger.id)
        |> Ledger.changeset(
          %{
            balance:
              ledger.balance +
                if(new_transaction.type == :income,
                  do: new_transaction.total_value,
                  else: -new_transaction.total_value
                )
          },
          ledger.owner_id
        )
        |> Repo.update!()

        broadcast(:transaction, ledger.id, {:saved, new_transaction})
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
      |> Transaction.changeset(attrs, transaction.ledger.id)

    case Repo.update(changeset) do
      {:ok, updated_transaction} ->
        fully_loaded_transaction =
          Transaction
          |> Repo.get!(updated_transaction.id)
          |> Repo.preload([:category, :investment_type, :profile])

        previous_total_value = transaction.total_value

        Ledger
        |> Repo.get!(updated_transaction.ledger_id)
        |> Ledger.changeset(
          %{
            balance:
              updated_transaction.ledger.balance +
                if(transaction.type == :income,
                  do: -previous_total_value,
                  else: previous_total_value
                ) +
                if(updated_transaction.type == :income,
                  do: updated_transaction.total_value,
                  else: -updated_transaction.total_value
                )
          },
          updated_transaction.ledger.owner_id
        )
        |> Repo.update!()

        broadcast(:transaction, updated_transaction.ledger_id, {:saved, fully_loaded_transaction})

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
      Ledger
      |> Repo.get!(deleted_transaction.ledger_id)
      |> Ledger.changeset(
        %{
          balance:
            deleted_transaction.ledger.balance +
              if(deleted_transaction.type == :income,
                do: -deleted_transaction.total_value,
                else: deleted_transaction.total_value
              )
        },
        deleted_transaction.ledger.owner_id
      )
      |> Repo.update!()

      broadcast(:transaction, transaction.ledger_id, {:deleted, deleted_transaction})
      {:ok, deleted_transaction}
    else
      {:error, _} = error -> error
    end
  end

  @doc """
  Create a ledger changeset for a user.
  """
  def change_ledger(%Scope{} = scope, %Ledger{} = ledger, attrs \\ %{}) do
    Ledger.changeset(ledger, attrs, scope.user.id)
  end

  @doc """
  Returns all ledgers for a user.
  """
  def list_ledgers(%Scope{} = scope) do
    from(b in PersonalFinance.Finance.Ledger,
      # Inclui orçamentos onde o usuário é o proprietário
      where: b.owner_id == ^scope.user.id,
      # OU
      or_where:
        b.id in subquery(
          # Nome da sua tabela de associação
          from(bu in "ledgers_users",
            where: bu.user_id == ^scope.user.id,
            select: bu.ledger_id
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
  Get ledger users including the owner.
  """
  def list_ledger_users(%Scope{} = scope, %Ledger{} = ledger) do
    from(bu in LedgersUsers,
      where: bu.ledger_id == ^ledger.id,
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.map(fn bu -> bu.user end)
    |> Enum.uniq()
    |> Enum.concat([ledger.owner])
    |> Enum.sort_by(& &1.email)
  end

  @doc """
  Get ledger invites.
  """
  def list_ledger_invites(%Scope{} = scope, %Ledger{} = ledger, status) do
    from(bi in LedgerInvite,
      where: bi.ledger_id == ^ledger.id,
      where: bi.status == ^status,
      preload: [:inviter, :invited_user]
    )
    |> Repo.all()
  end

  @doc """
  Updates a ledger.
  """
  def update_ledger(%Scope{} = scope, %Ledger{} = ledger, attrs) do
    with {:ok, ledger = %Ledger{}} <-
           ledger
           |> Ledger.changeset(attrs, scope.user.id)
           |> Repo.update() do
      {:ok, Repo.preload(ledger, [:owner])}
    end
  end

  @doc """
  Deletes a ledger.
  """
  def delete_ledger(%Scope{} = scope, %Ledger{} = ledger) do
    Repo.delete(ledger)
  end

  @doc """
  Returns a ledger by ID for a user.
  """
  def get_ledger(%Scope{} = scope, id) do
    from(b in PersonalFinance.Finance.Ledger,
      preload: [:owner],
      where:
        b.id == ^id and
          (b.owner_id == ^scope.user.id or
             b.id in subquery(
               from(bu in "ledgers_users",
                 where: bu.user_id == ^scope.user.id,
                 select: bu.ledger_id
               )
             ))
    )
    |> PersonalFinance.Repo.one()
  end

  @doc """
  Creates a ledger.
  """
  def create_ledger(%Scope{} = scope, attrs) do
    changeset =
      %Ledger{}
      |> Ledger.changeset(attrs, scope.user.id)

    case Repo.insert(changeset) do
      {:ok, new_ledger} ->
        {:ok, Repo.preload(new_ledger, [:owner])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Remove a user from a ledger.
  """
  def remove_ledger_user(%Scope{} = scope, %Ledger{} = ledger, user_id) do
    if ledger.owner_id != scope.user.id do
      {:error, "You are not the owner of this ledger."}
    else
      from(bu in LedgersUsers,
        where: bu.ledger_id == ^ledger.id and bu.user_id == ^user_id
      )
      |> Repo.delete_all()

      from(bi in LedgerInvite,
        where: bi.ledger_id == ^ledger.id and bi.invited_user_id == ^user_id
      )
      |> Repo.delete_all()

      {:ok, "User removed from ledger."}
    end
  end

  @doc """
  Creates default profiles for a ledger.
  """
  def create_default_profiles(%Scope{} = scope, %Ledger{} = ledger) do
    default_profile_attrs = %{
      "name" => "Eu",
      "description" => "Perfil principal do usuário",
      "is_default" => true,
      "ledger_id" => ledger.id
    }

    create_profile(scope, default_profile_attrs, ledger)
  end

  @doc """
  Creates default categories for a ledger.
  """
  def create_default_categories(%Scope{} = scope, %Ledger{} = ledger) do
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
        create_category(scope, category_attrs_map, ledger)
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
  Create a profile changeset for a ledger and user.
  """
  def change_profile(
        %Scope{} = scope,
        %Profile{} = profile,
        %Ledger{} = ledger,
        attrs \\ %{}
      ) do
    Profile.changeset(profile, attrs, ledger.id)
  end

  @doc """
  Returns a list of profiles for a ledger.
  """
  def list_profiles(%Scope{} = scope, ledger) do
    Profile
    |> where([p], p.ledger_id == ^ledger.id)
    |> Repo.all()
  end

  @doc """
  Return a profile by ID for a ledger.
  """
  def get_profile(%Scope{} = scope, ledger_id, id) do
    ledger = get_ledger(scope, ledger_id)

    if ledger == nil do
      nil
    else
      Profile
      |> Ecto.Query.preload(:ledger)
      |> Repo.get_by(id: id, ledger_id: ledger.id)
    end
  end

  @doc """
  Updates a profile.
  """
  def update_profile(%Scope{} = scope, %Profile{} = profile, attrs) do
    with {:ok, updated_profile = %Profile{}} <-
           profile
           |> Profile.changeset(attrs, profile.ledger.id)
           |> Repo.update() do
      broadcast(:profile, updated_profile.ledger_id, {:saved, updated_profile})
      {:ok, updated_profile}
    else
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Creates a profile for a ledger.
  """
  def create_profile(%Scope{} = scope, attrs, ledger) do
    with {:ok, profile = %Profile{}} <-
           %Profile{}
           |> Profile.changeset(attrs, ledger.id)
           |> Repo.insert() do
      broadcast(:profile, ledger.id, {:saved, profile})
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
        |> where([p], p.is_default == true and p.ledger_id == ^profile.ledger_id)
        |> Repo.one()

      from(t in Transaction,
        where: t.profile_id == ^profile.id and t.ledger_id == ^profile.ledger_id
      )
      |> Repo.update_all(set: [profile_id: default_profile.id])

      broadcast(:transaction, profile.ledger_id, :transactions_updated)

      with {:ok, deleted_profile} <- Repo.delete(profile) do
        broadcast(:profile, profile.ledger_id, {:deleted, deleted_profile})
        {:ok, deleted_profile}
      else
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Create a ledger invite
  """
  def create_ledger_invite(%Scope{} = scope, ledger, email) do
    if ledger.owner_id != scope.user.id do
      {:error, "You are not the owner of this ledger."}
    else
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64()
      expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(7 * 24 * 60 * 60, :second)

      attrs = %{
        ledger_id: ledger.id,
        email: email,
        token: token,
        inviter_id: scope.user.id,
        status: :pending,
        expires_at: expires_at
      }

      %LedgerInvite{}
      |> LedgerInvite.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Get a ledger invite by token
  """
  def get_ledger_invite_by_token(token) do
    Repo.get_by(LedgerInvite, token: token) |> Repo.preload([:ledger, :inviter, :invited_user])
  end

  @doc """
  Accept a ledger invite
  """
  def accept_ledger_invite(user, %LedgerInvite{} = invite) do
    if invite.status == :pending && user.email == invite.email &&
         (is_nil(invite.expires_at) ||
            NaiveDateTime.compare(NaiveDateTime.utc_now(), invite.expires_at) == :lt) do
      Repo.transaction(fn ->
        invite =
          invite
          |> LedgerInvite.changeset(%{status: :accepted, invited_user_id: user.id})
          |> Repo.update!()

        %LedgersUsers{}
        |> LedgersUsers.changeset(%{
          ledger_id: invite.ledger_id,
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
  Decline a ledger invite
  """
  def decline_ledger_invite(user, %LedgerInvite{} = invite) do
    if invite.status == :pending && user.email == invite.email &&
         (is_nil(invite.expires_at) ||
            NaiveDateTime.compare(NaiveDateTime.utc_now(), invite.expires_at) == :lt) do
      invite
      |> LedgerInvite.changeset(%{status: :declined})
      |> Repo.update()
    else
      {:error, "Invite is not valid or has expired."}
    end
  end

  @doc """
  Revoke a ledger invite
  """
  def revoke_ledger_invite(%Scope{} = scope, %Ledger{} = ledger, invite_id) do
    if ledger.owner_id != scope.user.id do
      {:error, "You are not the owner of this ledger."}
    else
      invite =
        LedgerInvite
        |> where([bi], bi.id == ^invite_id and bi.ledger_id == ^ledger.id)
        |> Repo.one()

      if invite do
        Repo.delete(invite)
      else
        {:error, "Invite not found."}
      end
    end
  end

  @doc """
  Create a recurring entry changeset for a ledger and user.
  """
  def change_recurring_entry(
        %Scope{} = scope,
        %PersonalFinance.Finance.RecurringEntry{} = recurring_entry,
        %Ledger{} = ledger,
        attrs \\ %{}
      ) do
    RecurringEntry.changeset(recurring_entry, attrs, ledger.id)
  end

  @doc """
  Create a recurring entry.
  """
  def create_recurring_entry(%Scope{} = scope, attrs, %Ledger{} = ledger) do
    with {:ok, recurring_entry = %RecurringEntry{}} <-
           %RecurringEntry{}
           |> RecurringEntry.changeset(attrs, ledger.id)
           |> Repo.insert() do
      fully_loaded_entry =
        recurring_entry
        |> Repo.preload(:category)

      broadcast(:recurring_entry, ledger.id, {:saved, fully_loaded_entry})
      {:ok, fully_loaded_entry}
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
      |> RecurringEntry.changeset(attrs, recurring_entry.ledger.id)

    case Repo.update(changeset) do
      {:ok, updated_recurring_entry} ->
        updated_recurring_entry =
          updated_recurring_entry
          |> Repo.preload(:category)

        broadcast(
          :recurring_entry,
          updated_recurring_entry.ledger_id,
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
    # update all transactions with this recurring entry to have no recurring entry

    from(t in Transaction,
      where:
        t.recurring_entry_id == ^recurring_entry.id and t.ledger_id == ^recurring_entry.ledger_id
    )
    |> Repo.update_all(set: [recurring_entry_id: nil])

    with {:ok, deleted_recurring_entry} <- Repo.delete(recurring_entry) do
      broadcast(:recurring_entry, recurring_entry.ledger.id, {:deleted, deleted_recurring_entry})
      {:ok, deleted_recurring_entry}
    else
      {:error, _} = error -> error
    end
  end

  @doc """
  List recurring entries for a ledger and profile
  """
  def list_recurring_entries(%Scope{} = scope, ledger_id, profile_id) do
    from(re in RecurringEntry,
      where: re.ledger_id == ^ledger_id and re.profile_id == ^profile_id,
      order_by: [asc: re.start_date],
      preload: [:category]
    )
    |> Repo.all()
  end

  @doc """
  Get a recurring entry by ID for a ledger and profile.
  """
  def get_recurring_entry(%Scope{} = scope, ledger_id, id) do
    from(re in RecurringEntry,
      where: re.ledger_id == ^ledger_id and re.id == ^id
    )
    |> Repo.one()
    |> Repo.preload([:ledger, :category, :profile])
  end

  @doc """
  Toggle the status of a recurring entry.
  """
  def toggle_recurring_entry_status(%Scope{} = scope, %RecurringEntry{} = recurring_entry) do
    new_status = not recurring_entry.is_active

    changeset =
      recurring_entry
      |> RecurringEntry.changeset(%{is_active: new_status}, recurring_entry.ledger.id)

    case Repo.update(changeset) do
      {:ok, updated_recurring_entry} ->
        broadcast(
          :recurring_entry,
          updated_recurring_entry.ledger_id,
          {:saved, updated_recurring_entry}
        )

        {:ok, updated_recurring_entry}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  List the pending recurrent transactions for a ledger.
  """
  def list_pending_recurrent_transactions(%Scope{} = scope, ledger_id, months) do
    today = Date.utc_today()

    recurring_entries =
      from(re in RecurringEntry,
        where: re.ledger_id == ^ledger_id and re.is_active == true,
        order_by: [asc: re.start_date, asc: re.description],
        preload: [:category, :profile]
      )
      |> Repo.all()

    current_month_start = Date.beginning_of_month(today)

    check_until =
      Date.add(today, months * 30)

    lookback_period_start =
      Date.add(today, -30)

    generated_transactions_in_period =
      from(t in Transaction,
        where:
          t.ledger_id == ^ledger_id and
            t.date >= ^lookback_period_start and
            t.date <= ^check_until and
            not is_nil(t.recurring_entry_id),
        select: %{recurring_entry_id: t.recurring_entry_id, date: t.date}
      )
      |> Repo.all()
      |> Enum.map(&{&1.recurring_entry_id, &1.date.month, &1.date.year})
      |> MapSet.new()

    Enum.flat_map(recurring_entries, fn %RecurringEntry{} = entry ->
      next_ocurrence_dates =
        calculate_next_ocurrence_dates(entry, today, check_until, months)

      Enum.filter(next_ocurrence_dates, fn date ->
        not Enum.any?(generated_transactions_in_period, fn {id, month, year} ->
          id == entry.id and
            year == date.year and
            (entry.frequency == :yearly or (entry.frequency == :monthly and month == date.month))
        end) and Date.compare(date, current_month_start) == :gt
      end)
      |> Enum.map(fn date ->
        %{
          id: entry.id,
          description: entry.description,
          value: entry.value,
          amount: entry.amount,
          date_expected: date,
          category: entry.category,
          profile: entry.profile,
          type: entry.type,
          recurring_entry: entry
        }
      end)
      |> Enum.sort_by(& &1.date_expected, Date)
    end)
  end

  @doc """
  Calculate the next occurrence dates for a recurring entry.
  """
  defp calculate_next_ocurrence_dates(
         %RecurringEntry{} = entry,
         today,
         check_until,
         max_ocurrences
       ) do
    current_date = max_date(today, entry.start_date)

    ocurrences =
      case entry.frequency do
        :monthly ->
          first_occurrence =
            case Date.new(current_date.year, current_date.month, entry.start_date.day) do
              {:ok, date} ->
                if Date.compare(date, current_date) in [:gt, :eq] do
                  date
                else
                  Date.new(
                    date.year,
                    date.month + 1,
                    entry.start_date.day
                  )
                  |> case do
                    {:ok, next_date} -> next_date
                    {:error, _} -> Date.add(date, 30)
                  end
                end

              {:error, _} ->
                Date.end_of_month(
                  Date.add(current_date, 30 - current_date.day + entry.start_date.month - 1)
                )
            end

          Stream.unfold({first_occurrence, 0}, fn
            {date, n} when n < max_ocurrences ->
              if Date.compare(date, check_until) == :lt and
                   Date.compare(date, entry.end_date) == :lt do
                {date,
                 {Date.new(
                    date.year,
                    date.month + 1,
                    entry.start_date.day
                  )
                  |> case do
                    {:ok, next_date} -> next_date
                    {:error, _} -> Date.add(date, 30)
                  end, n + 1}}
              else
                nil
              end

            _ ->
              nil
          end)
          |> Enum.to_list()

        :yearly ->
          max_ocurrences = 1

          first_occurrence =
            case Date.new(current_date.year, entry.start_date.month, entry.start_date.day) do
              {:ok, date} ->
                if Date.compare(date, current_date) in [:gt, :eq] do
                  date
                else
                  Date.new(
                    date.year + 1,
                    date.month,
                    date.day
                  )
                  |> case do
                    {:ok, next_date} -> next_date
                    {:error, _} -> Date.add(date, 365)
                  end
                end

              {:error, _} ->
                Date.end_of_month(
                  Date.add(current_date, 365 - current_date.day + entry.start_date.day - 1)
                )
            end

          Stream.unfold({first_occurrence, 0}, fn
            {date, n} when n < max_ocurrences ->
              if Date.compare(date, check_until) == :lt and
                   Date.compare(date, entry.end_date) == :lt do
                {date,
                 {Date.new(
                    date.year + 1,
                    date.month,
                    date.day
                  )
                  |> case do
                    {:ok, next_date} -> next_date
                    {:error, _} -> Date.add(date, 365)
                  end, n + 1}}
              else
                nil
              end

            _ ->
              nil
          end)
          |> Enum.to_list()
      end

    ocurrences
  end

  defp max_date(date1, date2) do
    if Date.compare(date1, date2) == :gt, do: date1, else: date2
  end

  @doc """
  Generate a transaction from a recurring entry.
  """
  def confirm_recurring_transaction(
        %Scope{} = scope,
        %Ledger{} = ledger,
        id
      ) do
    if ledger do
      recurring_entry = get_recurring_entry(scope, ledger.id, id)

      transaction_attrs = %{
        "description" => recurring_entry.description,
        "value" => recurring_entry.value,
        "amount" => recurring_entry.amount,
        "total_value" => recurring_entry.value * recurring_entry.amount,
        "date" => Date.utc_today(),
        "category_id" => recurring_entry.category_id,
        "profile_id" => recurring_entry.profile_id,
        "ledger_id" => ledger.id,
        "recurring_entry_id" => recurring_entry.id,
        "type" => recurring_entry.type
      }

      create_transaction(scope, transaction_attrs, ledger)
    else
      {:error, "Ledger not found."}
    end
  end

  @doc """
  Get balance for a month in a ledger for a specific profile.
  """
  def get_month_balance(%Scope{} = scope, ledger_id, date, profile_id \\ nil) do
    month_start = Date.beginning_of_month(date)
    month_end = Date.end_of_month(date)

    base_query =
      from(t in Transaction,
        where: t.ledger_id == ^ledger_id and t.date >= ^month_start and t.date <= ^month_end
      )

    query_with_profile =
      if profile_id do
        from(t in base_query, where: t.profile_id == ^profile_id)
      else
        base_query
      end

    total_incomes =
      from(t in query_with_profile,
        where: t.type == :income,
        select: sum(t.total_value)
      )
      |> Repo.one()
      |> case do
        nil -> 0.0
        value -> value
      end

    total_expenses =
      from(t in query_with_profile,
        where: t.type == :expense,
        select: sum(t.total_value)
      )
      |> Repo.one()
      |> case do
        nil -> 0.0
        value -> value
      end

    %{
      total_incomes: total_incomes,
      total_expenses: total_expenses,
      balance: total_incomes - total_expenses
    }
  end

  @doc """
  Get the balance for a ledger for a specific profile.
  """
  def get_balance(%Scope{} = scope, ledger_id, profile_id \\ nil) do
    base_query =
      from(t in Transaction,
        where: t.ledger_id == ^ledger_id
      )

    query_with_profile =
      if profile_id do
        from(t in base_query, where: t.profile_id == ^profile_id)
      else
        base_query
      end

    total_incomes =
      from(t in query_with_profile,
        where: t.type == :income,
        select: sum(t.total_value)
      )
      |> Repo.one()
      |> case do
        nil -> 0.0
        value -> value
      end

    total_expenses =
      from(t in query_with_profile,
        where: t.type == :expense,
        select: sum(t.total_value)
      )
      |> Repo.one()
      |> case do
        nil -> 0.0
        value -> value
      end

    total_incomes - total_expenses
  end

  @doc """
  Subscribes to scoped notifications abour any finance related changes.

  The broadcasted message match the pattern
  * {:saved, %Resource{}}
  * {:deleted, %Resource{}}
  """
  def subscribe_finance(resource, ledger_id) do
    IO.inspect(
      "Subscribing to finance notifications for resource: #{resource} and ledger_id: #{ledger_id}"
    )

    Phoenix.PubSub.subscribe(PersonalFinance.PubSub, "finance:#{ledger_id}:#{resource}")
  end

  defp broadcast(resource, ledger_id, message) do
    IO.inspect(
      "Broadcasting finance notification for resource: #{resource}, ledger_id: #{ledger_id}"
    )

    Phoenix.PubSub.broadcast(
      PersonalFinance.PubSub,
      "finance:#{ledger_id}:#{resource}",
      message
    )
  end
end
