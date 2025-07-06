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
alias PersonalFinance.Finance.{InvestmentType}

IO.puts("Iniciando seed do banco de dados...")

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

cripto_type = Repo.get_by(InvestmentType, name: "Cripto")

cripto_type =
  unless cripto_type do
    case Repo.insert(%InvestmentType{
           name: "Cripto",
           description: "Investimento em criptomoedas"
         }) do
      {:ok, crypto_type} ->
        IO.puts("  Criado tipo de investimento: #{crypto_type.name}")
        crypto_type

      {:error, changeset} ->
        IO.puts("Erro ao criar tipo: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

renda_fixa_type = Repo.get_by(InvestmentType, name: "Renda Fixa")

renda_fixa_type =
  unless renda_fixa_type do
    case Repo.insert(%InvestmentType{
           name: "Renda Fixa",
           description: "Investimento em renda fixa"
         }) do
      {:ok, rf_type} ->
        IO.puts("  Criado tipo de investimento: #{rf_type.name}")
        rf_type

      {:error, changeset} ->
        IO.puts("Erro ao criar tipo: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

IO.puts("Seed do banco de dados concluída com sucesso!")
