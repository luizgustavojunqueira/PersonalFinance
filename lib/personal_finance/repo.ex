defmodule PersonalFinance.Repo do
  use Ecto.Repo,
    otp_app: :personal_finance,
    adapter: Ecto.Adapters.SQLite3
end
