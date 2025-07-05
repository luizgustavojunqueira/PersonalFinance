defmodule PersonalFinance.Repo.Migrations.CreateBudgetInvite do
  use Ecto.Migration

  def change do
    create table(:budget_invites) do
      add :email, :string, null: false
      add :token, :string, null: false
      add :status, :string, default: "pending", null: false
      add :expires_at, :naive_datetime, null: false

      add :budget_id, references(:budgets, on_delete: :delete_all), null: false
      add :inviter_id, references(:users, on_delete: :nothing), null: false
      add :invited_user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:budget_invites, [:email, :budget_id],
             name: :budget_invites_email_budget_id_index
           )

    create unique_index(:budget_invites, [:token], name: :budget_invites_token_index)
  end
end
