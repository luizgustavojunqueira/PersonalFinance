defmodule PersonalFinance.Workers.YieldsWorker do
  alias PersonalFinance.Investment
  alias PersonalFinance.Finance.Ledger
  alias PersonalFinance.Repo
  use Oban.Worker, queue: :yields, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{} = args}) do
    case Map.get(args, "ledger_id") do
      nil ->
        Ledger
        |> Repo.all()
        |> Enum.each(&Investment.generate_yields(&1))

        :ok

      ledger_id ->
        case Repo.get(Ledger, ledger_id) do
          nil ->
            {:error, :ledger_not_found}

          ledger ->
            Investment.generate_yields(ledger)
            :ok
        end
    end
  end
end
