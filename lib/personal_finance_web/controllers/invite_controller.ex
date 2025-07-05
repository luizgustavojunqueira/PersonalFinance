defmodule PersonalFinanceWeb.InviteController do
  use PersonalFinanceWeb, :controller

  alias PersonalFinance.Finance

  def show_invitation(conn, %{"token" => token}) do
    case Finance.get_budget_invite_by_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Convite inválido ou não encontrado.")
        |> redirect(to: ~p"/budgets")

      %Finance.BudgetInvite{status: :accepted} = invite ->
        conn
        |> put_flash(:info, "Este convite já foi aceito.")
        |> redirect(to: ~p"/budgets/#{invite.budget_id}/home")

      %Finance.BudgetInvite{status: :declined} = _invite ->
        conn
        |> put_flash(:error, "Este convite foi rejeitado.")
        |> redirect(to: ~p"/budgets")

      %Finance.BudgetInvite{status: :pending, expires_at: expires_at} = invite
      when not is_nil(expires_at) ->
        if NaiveDateTime.compare(NaiveDateTime.utc_now(), invite.expires_at) == :gt do
          conn
          |> put_flash(:error, "Este convite expirou.")
          |> redirect(to: ~p"/budgets")
        else
          user = conn.assigns.current_scope.user

          if user && invite.email == user.email do
            # Usuário logado e o convite é para ele
            conn
            |> render(:show_invitation,
              invite: invite,
              page_title: "Aceitar Convite"
            )
          else
            conn
            |> redirect(to: ~p"/budgets")
          end
        end
    end
  end

  def join(conn, %{"token" => token}) do
    case Finance.get_budget_invite_by_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Convite inválido ou não encontrado.")
        |> redirect(to: ~p"/budgets")

      invite ->
        user = conn.assigns.current_scope.user

        if invite.email == user.email do
          case Finance.accept_budget_invite(user, invite) do
            {:ok, _invite} ->
              conn
              |> put_flash(:info, "Convite aceito com sucesso! Você agora é membro do orçamento.")
              |> redirect(to: ~p"/budgets/#{invite.budget_id}/home")

            {:error, _reason} ->
              conn
              |> put_flash(
                :error,
                "Não foi possível aceitar o convite. Por favor, tente novamente."
              )
              |> redirect(to: ~p"/budgets")
          end
        else
          conn
          |> put_flash(:error, "Convite inválido")
          |> redirect(to: ~p"/budgets")
        end
    end
  end

  def decline(conn, %{"token" => token}) do
    case Finance.get_budget_invite_by_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Convite inválido ou não encontrado.")
        |> redirect(to: ~p"/budgets")

      invite ->
        user = conn.assigns.current_scope.user

        if invite.email == user.email do
          case Finance.decline_budget_invite(user, invite) do
            {:ok, _invite} ->
              conn
              |> put_flash(:info, "Convite rejeitado.")
              |> redirect(to: ~p"/budgets")

            {:error, _reason} ->
              conn
              |> put_flash(
                :error,
                "Não foi possível rejeitar o convite. Por favor, tente novamente."
              )
              |> redirect(to: ~p"/budgets")
          end
        else
          conn
          |> put_flash(:error, "Convite inválido")
          |> redirect(to: ~p"/budgets")
        end
    end
  end
end
