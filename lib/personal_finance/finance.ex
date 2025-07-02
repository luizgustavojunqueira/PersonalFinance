defmodule PersonalFinance.Finance do
  alias PersonalFinance.Repo
  alias PersonalFinance.Accounts.Scope
  alias PersonalFinance.Finance.{Transaction, Category, InvestmentType, Profile, Budget}
  import Ecto.Query

  @doc """
  Retorna a lista de transações para um orçamento
  """
  def list_transactions_for_budget(budget) do
    from(t in Transaction,
      order_by: [desc: t.date],
      where: t.budget_id == ^budget.id
    )
    |> Ecto.Query.preload([:category, :investment_type, :profile])
    |> Repo.all()
  end

  @doc """
  Retorna a lista de profiles para um orçamento
  """
  def list_profiles_for_budget(budget) do
    Profile
    |> where([p], p.budget_id == ^budget.id)
    |> Repo.all()
  end

  @doc """
  Cria uma transação.
  """
  def create_transaction(attrs, budget_id) do
    attrs =
      if Map.get(attrs, "budget_id") do
        attrs
      else
        Map.put(attrs, "budget_id", budget_id)
      end

    attrs =
      if Map.get(attrs, "category_id") do
        attrs
      else
        default_category =
          Category
          |> where([c], c.is_default == true and c.budget_id == ^budget_id)
          |> Repo.one()

        Map.put(attrs, "category_id", default_category.id)
      end

    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
    |> handle_transaction_change()
  end

  @doc """
  Atualiza uma transação.
  """
  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
    |> handle_transaction_change()
  end

  @doc """
  Deleta uma transação.
  """
  def delete_transaction(%Transaction{} = transaction) do
    Repo.delete(transaction)
    |> handle_transaction_change()
  end

  @doc """
  Retorna tipos de investimento.
  """
  def list_investment_types do
    InvestmentType
    |> Repo.all()
  end

  @doc """
  Retorna categoria por nome
  """
  def get_category_by_name(name, budget_id) do
    Category
    |> where([c], c.name == ^name and c.budget_id == ^budget_id)
    |> Repo.one()
  end

  @doc """
  Retorna transação por ID.
  """
  def get_transaction!(id) do
    Transaction
    |> Repo.get!(id)
    |> Repo.preload([:category, :investment_type, :profile])
  end

  @doc """
  Retorna o valor total de transações por categoria.
  """
  def get_total_value_by_category(category_id, transactions) do
    transactions
    |> Enum.filter(fn t -> t.category_id == category_id end)
    |> Enum.reduce(0, fn t, acc -> acc + t.total_value end)
  end

  @doc """
  Returns the list of categories for a budget.
  """
  def list_categories_for_budget(budget) do
    Category
    |> where([c], c.budget_id == ^budget.id)
    |> Repo.all()
  end

  @doc """
  Creates a category.
  """
  def create_category(attrs, budget_id) do
    attrs =
      if Map.get(attrs, "budget_id") do
        attrs
      else
        Map.put(attrs, "budget_id", budget_id)
      end

    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
    |> handle_category_change()
  end

  @doc """
  Updates a category.
  """
  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
    |> handle_category_change()
  end

  @doc """
  Deletes a category and resets transactions to default category.
  """
  def delete_category(%Category{} = category) do
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

      Repo.delete(category)
    end
  end

  @doc """
  Returns a category by ID.
  """
  def get_category!(id) do
    Category
    |> Repo.get!(id)
    |> Repo.preload(:budget)
  end

  @doc """
  Returns all budgets for a user.
  """
  def list_budgets_for_user(user) do
    from(b in Budget,
      where: b.owner_id == ^user.id,
      distinct: true
    )
    |> Ecto.Query.preload(:owner)
    |> Repo.all()
  end

  @doc """
  Returns a budget by ID.
  """
  def get_budget_by_id(budget_id) do
    from(b in Budget, where: b.id == ^budget_id)
    |> Repo.one()
  end

  @doc """
  Creates a budget.
  """
  def create_budget(attrs) do
    Repo.transaction(fn ->
      case %Budget{} |> Budget.changeset(attrs) |> Repo.insert() do
        {:ok, budget} ->
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

          default_profile_attrs = %{
            "name" => "Eu",
            "description" => "Perfil principal do usuário",
            "is_default" => true,
            "budget_id" => budget.id
          }

          # Create default profile
          case create_profile(default_profile_attrs, budget.id) do
            {:ok, _profile} ->
              :ok

            {:error, changeset} ->
              IO.inspect(changeset, label: "Failed to create default profile")
              raise Ecto.NoResultsError, message: "Failed to create default profile"
          end

          # Create default categories
          results =
            Enum.map(default_categories_attrs, fn category_attrs_map ->
              create_category(category_attrs_map, budget.id)
            end)

          if Enum.all?(results, fn result ->
               case result do
                 {:ok, _category} -> true
                 {:error, _changeset} -> false
               end
             end) do
            budget
          else
            failed_results =
              Enum.filter(results, fn result ->
                case result do
                  {:ok, _category} -> false
                  {:error, _changeset} -> true
                end
              end)

            IO.inspect(failed_results, label: "Failed to create categories")

            raise Ecto.NoResultsError, message: "Failed to create all default categories"
          end

        {:error, budget_changeset} ->
          # Budget creation failed, return its errors directly (transaction will rollback implicitly)
          {:error, budget_changeset}
      end
    end)
  end

  @doc """
  Updates a budget.
  """
  def update_budget(%Budget{} = budget, attrs) do
    budget
    |> Budget.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a budget.
  """
  def delete_budget(%Budget{} = budget) do
    Repo.delete(budget)
  end

  @doc """
  Creates a profile for a budget.
  """
  def create_profile(attrs, budget_id) do
    attrs =
      if Map.get(attrs, "budget_id") do
        attrs
      else
        Map.put(attrs, "budget_id", budget_id)
      end

    IO.inspect(attrs, label: "Creating profile with attrs")

    %Profile{}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Delete a profile by id
  """
  def delete_profile_by_id(id) do
    profile = Repo.get!(Profile, id)

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

      Repo.delete(profile)
    end
  end

  @doc """
  Returns a profile by ID.
  """
  def get_profile_by_id(id, budget_id) do
    Profile
    |> where([p], p.id == ^id and p.budget_id == ^budget_id)
    |> Repo.one()
  end

  @doc """
  Update a profile.
  """
  def update_profile_by_id(profile_id, attrs, budget_id) do
    profile = get_profile_by_id(profile_id, budget_id)

    if profile do
      profile
      |> Profile.changeset(attrs)
      |> Repo.update()
    else
      {:error, "Profile not found"}
    end
  end

  defp handle_category_change({:ok, %Category{} = category}) do
    Phoenix.PubSub.broadcast(
      PersonalFinance.PubSub,
      "categories_updates:#{category.budget_id}",
      {:category_changed, category.budget_id}
    )

    {:ok, category}
  end

  defp handle_category_change({:error, changeset}), do: {:error, changeset}

  defp handle_transaction_change({:ok, %Transaction{} = transaction}) do
    preloaded_transaction = Repo.preload(transaction, [:category, :investment_type, :profile])

    Phoenix.PubSub.broadcast(
      PersonalFinance.PubSub,
      "transactions_updates:#{preloaded_transaction.budget_id}",
      {:transaction_changed, preloaded_transaction.budget_id}
    )

    {:ok, preloaded_transaction}
  end

  defp handle_transaction_change({:error, _} = error), do: error

  def get_budget!(%Scope{} = scope, id) do
    Budget
    |> Ecto.Query.preload(:owner)
    |> Repo.get_by!(id: id, owner_id: scope.user.id)
  end

  def get_profile!(%Scope{} = scope, budget_id, id) do
    budget = get_budget!(scope, budget_id)

    Profile
    |> Ecto.Query.preload(:budget)
    |> Repo.get_by!(id: id, budget_id: budget.id)
  end

  def change_profile(
        %Scope{} = scope,
        %Profile{} = profile,
        %Budget{} = budget,
        attrs \\ %{}
      ) do
    true = scope.user.id == budget.owner_id

    Profile.changeset(profile, attrs, budget.id)
  end

  def update_profile(%Scope{} = scope, %Profile{} = profile, attrs) do
    true = scope.user.id == profile.budget.owner_id

    profile
    |> Profile.changeset(attrs, profile.budget.id)
    |> Repo.update()
  end

  def create_profile(%Scope{} = scope, attrs, budget_id) do
    budget = get_budget!(scope, budget_id)

    %Profile{}
    |> Profile.changeset(attrs, budget.id)
    |> Repo.insert()
  end

  def delete_profile(%Scope{} = scope, %Profile{} = profile) do
    true = scope.user.id == profile.budget.owner_id

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

      Repo.delete(profile)
    end
  end
end
