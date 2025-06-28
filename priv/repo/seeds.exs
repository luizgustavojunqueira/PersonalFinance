# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     PersonalFinance.Repo.insert!(%PersonalFinance.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias PersonalFinance.Repo
alias PersonalFinance.Finance.{Category, InvestmentType, Profile, Transaction}
alias PersonalFinance.Accounts.User

IO.puts("Iniciando seed do banco de dados...")

test_user_email = "luiz@gmail.com"
test_user = Repo.get_by(User, email: test_user_email)

test_user =
  unless test_user do
    IO.puts("Criando usuários de teste: #{test_user_email}...")

    attrs = %{
      email: test_user_email,
      name: "Luiz Gustavo",
      password: "luizgustavo2004",
      password_confirmation: "luizgustavo2004",
      confirmed_at: NaiveDateTime.utc_now()
    }

    case PersonalFinance.Accounts.register_user(attrs) do
      {:ok, user} ->
        IO.puts("Usuário #{test_user_email} criado e confirmado.")
        user

      {:error, changeset} ->
        IO.puts("Erro ao criar usuário #{test_user_email}: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

IO.puts("Populando categorias...")
investimentos_category = Repo.get_by(Category, name: "Investimentos")

investimentos_category =
  unless investimentos_category do
    case Repo.insert(%Category{
           name: "Investimentos",
           description: "Transações relacionadas a investimentos",
           user_id: test_user.id
         }) do
      {:ok, category} ->
        IO.puts("Criada categoria: #{category.name}")
        category

      {:error, changeset} ->
        IO.puts("Erro ao criar categoria: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

prazeres_category = Repo.get_by(Category, name: "Prazeres")

prazeres_category =
  unless prazeres_category do
    case Repo.insert(%Category{
           name: "Prazeres",
           description: "Despesas relacionadas à prazeres",
           user_id: test_user.id
         }) do
      {:ok, category} ->
        IO.puts("Criada categoria: #{category.name}")
        category

      {:error, changeset} ->
        IO.puts("Erro ao criar categoria: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

IO.puts("Populando tipos de investimento...")
acoes_type = Repo.get_by(InvestmentType, name: "Ações")

acoes_type =
  unless acoes_type do
    case Repo.insert(%InvestmentType{
           name: "Ações",
           description: "Investimento em ações de empresas"
         }) do
      {:ok, acoes_type} ->
        IO.puts("  Criado tipo de investimento: #{acoes_type.name}")
        acoes_type

      {:error, changeset} ->
        IO.puts("Erro ao criar tipo: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

fundo_imobiliario_type = Repo.get_by(InvestmentType, name: "Fundo Imobiliário")

fundo_imobiliario_type =
  unless fundo_imobiliario_type do
    case Repo.insert(%InvestmentType{
           name: "Fundo Imobiliário",
           description: "Investimento em fundos de investimento imobiliário (FIIs)"
         }) do
      {:ok, fi_type} ->
        IO.puts("  Criado tipo de investimento: #{fi_type.name}")
        fi_type

      {:error, changeset} ->
        IO.puts("Erro ao criar tipo: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

IO.puts("Populando perfis...")
eu_profile = Repo.get_by(Profile, name: "Eu", user_id: test_user.id)

eu_profile =
  unless eu_profile do
    case Repo.insert(%Profile{name: "Eu", user_id: test_user.id}) do
      {:ok, profile} ->
        IO.puts("  Criado profile: #{profile.name}")
        profile

      {:error, changeset} ->
        IO.puts("Erro ao criar profile: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

conjuge_profile = Repo.get_by(Profile, name: "Cônjuge", user_id: test_user.id)

conjuge_profile =
  unless conjuge_profile do
    case Repo.insert(%Profile{name: "Cônjuge", user_id: test_user.id}) do
      {:ok, profile} ->
        IO.puts("  Criado profile: #{profile.name}")
        profile

      {:error, changeset} ->
        IO.puts("Erro ao criar profile: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

IO.puts("Populando transações...")

# Transação de prazer
unless Repo.get_by(Transaction, description: "Jantar Romântico", profile_id: eu_profile.id) do
  Repo.insert!(%Transaction{
    value: 120.0,
    amount: 1.0,
    total_value: 120.0,
    description: "Jantar Romântico",
    date: ~D[2024-06-25],
    category_id: prazeres_category.id,
    profile_id: eu_profile.id,
    user_id: test_user.id
  })

  IO.puts("  Criada transação: Jantar Romântico")
end

unless Repo.get_by(Transaction, description: "Ações", profile_id: eu_profile.id) do
  Repo.insert!(%Transaction{
    value: 10.0,
    amount: 10.0,
    total_value: 100.0,
    description: "Ações",
    date: ~D[2024-06-25],
    investment_type_id: acoes_type.id,
    category_id: investimentos_category.id,
    profile_id: eu_profile.id,
    user_id: test_user.id
  })

  IO.puts("  Criada transação: Jantar Romântico")
end

IO.puts("✅ Seed do banco de dados concluída!")
