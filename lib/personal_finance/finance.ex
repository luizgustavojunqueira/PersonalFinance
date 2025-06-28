defmodule PersonalFinance.Finance do
  alias PersonalFinance.Repo
  alias PersonalFinance.Finance.{Transaction, Category, InvestmentType, Profile}
  import Ecto.Query

  @doc """
  Retorna a lista de transações para um usuário.
  """
  def list_transactions_for_user(user) do
    from(t in Transaction,
      order_by: [desc: t.date],
      where: t.user_id == ^user.id
    )
    |> Ecto.Query.preload([:category, :investment_type, :profile])
    |> Repo.all()
  end

  @doc """
  Retorna a lista de categorias para um usuário.
  """
  def list_categories_for_user(user) do
    Category
    |> where([c], c.user_id == ^user.id)
    |> Repo.all()
  end

  @doc """
  Retorna a lista de profiles para um usuário.
  """
  def list_profiles_for_user(user) do
    Profile
    |> where([p], p.user_id == ^user.id)
    |> Repo.all()
  end

  @doc """
  Cria uma transação.
  """
  def create_transaction(attrs) do
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

  # ... outras funções para Category, InvestmentType, Profile ...

  # Helper para pré-carregar e publicar
  defp handle_transaction_change({:ok, %Transaction{} = transaction}) do
    preloaded_transaction = Repo.preload(transaction, [:category, :investment_type, :profile])

    Phoenix.PubSub.broadcast(
      PersonalFinance.PubSub,
      "transactions_updates:#{preloaded_transaction.user_id}",
      {:transaction_changed, preloaded_transaction.user_id}
    )

    {:ok, preloaded_transaction}
  end

  defp handle_transaction_change({:error, _} = error), do: error
end
