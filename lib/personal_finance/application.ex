defmodule PersonalFinance.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PersonalFinanceWeb.Telemetry,
      PersonalFinance.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:personal_finance, :ecto_repos), skip: skip_migrations?()},
      {Oban, Application.fetch_env!(:personal_finance, Oban)},
      {DNSCluster, query: Application.get_env(:personal_finance, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PersonalFinance.PubSub},
      # Start a worker by calling: PersonalFinance.Worker.start_link(arg)
      # {PersonalFinance.Worker, arg},
      # Start to serve requests, typically the last entry
      PersonalFinanceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: PersonalFinance.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PersonalFinanceWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    System.get_env("RELEASE_NAME") == nil
  end
end
