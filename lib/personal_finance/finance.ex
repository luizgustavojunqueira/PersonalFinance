defmodule PersonalFinance.Finance do
  alias PersonalFinance.Repo
  alias PersonalFinance.Accounts.Scope
  alias PersonalFinance.Finance.{Transaction, Category, InvestmentType, Profile, Budget}
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
    true = scope.user.id == budget.owner_id

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
    true = scope.user.id == budget.owner_id

    Category.changeset(category, attrs, budget.id)
  end

  @doc """
  Returns a category by ID.
  """
  def get_category(%Scope{} = scope, id, %Budget{} = budget) do
    true = scope.user.id == budget.owner_id

    Category
    |> Repo.get(id)
    |> Repo.preload(:budget)
  end

  @doc """
  Returns a category by name for a budget.
  """
  def get_category_by_name(name, %Scope{} = scope, budget) do
    true = scope.user.id == budget.owner_id

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
    true = scope.user.id == budget.owner_id

    %Category{}
    |> Category.changeset(attrs, budget.id)
    |> Repo.insert()
  end

  @doc """
  Updates a category.
  """
  def update_category(%Scope{} = scope, %Category{} = category, attrs) do
    true = scope.user.id == category.budget.owner_id
    changeset = category |> Category.changeset(attrs, category.budget.id)

    case Repo.update(changeset) do
      {:ok, updated_category} ->
        fully_loaded_category =
          Category |> Repo.get!(updated_category.id) |> Repo.preload([:budget])

        {:ok, fully_loaded_category}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a category and resets transactions to default category.
  """
  def delete_category(%Scope{} = scope, %Category{} = category) do
    true = scope.user.id == category.budget.owner_id

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
  Create a transaction changeset for a budget and user.
  """
  def change_transaction(
        %Scope{} = scope,
        %Transaction{} = transaction,
        %Budget{} = budget,
        attrs \\ %{}
      ) do
    true = scope.user.id == budget.owner_id

    Transaction.changeset(transaction, attrs, budget.id)
  end

  @doc """
  Retorna transação por ID.
  """
  def get_transaction(%Scope{} = scope, id, %Budget{} = budget) do
    true = scope.user.id == budget.owner_id

    Transaction
    |> Repo.get_by(id: id, budget_id: budget.id)
    |> Repo.preload([:budget, :category, :investment_type, :profile])
  end

  @doc """
  Retorna a lista de transações para um orçamento
  """
  def list_transactions(%Scope{} = scope, budget) do
    true = scope.user.id == budget.owner_id

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
    true = scope.user.id == budget.owner_id

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

    case Repo.insert(changeset) do
      {:ok, new_transaction} ->
        # Carregue as associações aqui antes de retornar!
        {:ok, Repo.preload(new_transaction, [:category, :investment_type, :profile])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Atualiza uma transação.
  """
  def update_transaction(%Scope{} = scope, %Transaction{} = transaction, attrs) do
    true = scope.user.id == transaction.budget.owner_id

    changeset =
      transaction
      |> Transaction.changeset(attrs, transaction.budget.id)

    case Repo.update(changeset) do
      {:ok, updated_transaction} ->
        fully_loaded_transaction =
          Transaction
          |> Repo.get!(updated_transaction.id)
          |> Repo.preload([:category, :investment_type, :profile])

        {:ok, fully_loaded_transaction}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deleta uma transação.
  """
  def delete_transaction(%Scope{} = scope, %Transaction{} = transaction) do
    true = scope.user.id == transaction.budget.owner_id

    Repo.delete(transaction)
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
    from(b in Budget,
      where: b.owner_id == ^scope.user.id,
      distinct: true
    )
    |> Ecto.Query.preload(:owner)
    |> Repo.all()
  end

  @doc """
  Updates a budget.
  """
  def update_budget(%Scope{} = scope, %Budget{} = budget, attrs) do
    budget
    |> Budget.changeset(attrs, scope.user.id)
    |> Repo.update()
  end

  @doc """
  Deletes a budget.
  """
  def delete_budget(%Scope{} = scope, %Budget{} = budget) do
    true = scope.user.id == budget.owner_id
    Repo.delete(budget)
  end

  @doc """
  Returns a budget by ID for a user.
  """
  def get_budget(%Scope{} = scope, id) do
    Budget
    |> Ecto.Query.preload(:owner)
    |> Repo.get_by(id: id, owner_id: scope.user.id)
  end

  @doc """
  Creates a budget.
  """
  def create_budget(%Scope{} = scope, attrs) do
    %Budget{}
    |> Budget.changeset(attrs, scope.user.id)
    |> Repo.insert()
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
    true = scope.user.id == budget.owner_id

    Profile.changeset(profile, attrs, budget.id)
  end

  @doc """
  Returns a list of profiles for a budget.
  """
  def list_profiles(%Scope{} = scope, budget) do
    true = scope.user.id == budget.owner_id

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
    true = scope.user.id == profile.budget.owner_id

    profile
    |> Profile.changeset(attrs, profile.budget.id)
    |> Repo.update()
  end

  @doc """
  Creates a profile for a budget.
  """
  def create_profile(%Scope{} = scope, attrs, budget) do
    true = scope.user.id == budget.owner_id

    %Profile{}
    |> Profile.changeset(attrs, budget.id)
    |> Repo.insert()
  end

  @doc """
  Deletes a profile and resets transactions to default profile.
  """
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
