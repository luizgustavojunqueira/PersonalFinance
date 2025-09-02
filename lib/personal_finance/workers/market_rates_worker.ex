defmodule PersonalFinance.Workers.MarketRatesWorker do
  use Oban.Worker, queue: :market_rates, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{} = args}) do
    case Map.get(args, "type") do
      nil ->
        PersonalFinance.Investment.fetch_and_store_market_rates(nil)
        :ok

      type ->
        case PersonalFinance.Investment.fetch_and_store_market_rate(type) do
          {:ok, _market_rate} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
