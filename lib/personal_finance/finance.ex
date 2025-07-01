defmodule PersonalFinance.Finance do
  alias PersonalFinance.Repo
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
  def create_transaction(attrs) do
    attrs =
      if Map.get(attrs, "category_id") do
        attrs
      else
        budget_id = Map.get(attrs, "budget_id")

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
  def get_category_by_name(name) do
    Category
    |> where([c], c.name == ^name)
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
  def create_category(attrs) do
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
    |> Repo.all()
  end

  def get_budget_by_id(budget_id) do
    from(b in Budget, where: b.id == ^budget_id)
    |> Repo.one()
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
end
