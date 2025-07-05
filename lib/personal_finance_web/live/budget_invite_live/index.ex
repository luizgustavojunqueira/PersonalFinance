defmodule PersonalFinanceWeb.BudgetInviteLive do
  use PersonalFinanceWeb, :live_view

  alias PersonalFinance.Finance

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Finance.get_budget_invite_by_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Convite inválido ou não encontrado.")
         # Redireciona para um local seguro
         |> push_navigate(to: ~p"/budgets")}

      %Finance.BudgetInvite{status: :accepted} = invite ->
        {:ok,
         socket
         |> put_flash(:info, "Este convite já foi aceito.")
         # Redireciona para o orçamento
         |> push_navigate(to: ~p"/budgets/#{invite.budget_id}/home")}

      %Finance.BudgetInvite{status: :rejected} = _invite ->
        {:ok,
         socket
         |> put_flash(:error, "Este convite foi rejeitado.")
         |> push_navigate(to: ~p"/budgets")}

      %Finance.BudgetInvite{} = invite ->
        # O convite é válido e pendente
        # Assume que você tem current_user no socket
        current_user = socket.assigns.current_scope.user

        if current_user do
          # Usuário logado: tentar aceitar o convite
          handle_acceptance(socket, invite, current_user)
        else
          # Usuário não logado: pedir para fazer login ou se registrar
          {:ok,
           assign(socket,
             invite: invite,
             page_title: "Aceitar Convite",
             show_login_register: true
           )}
        end
    end
  end

  def handle_event("reject_invite", _params, socket) do
    invite = socket.assigns.invite

    case Finance.decline_budget_invite(socket.assigns.current_scope, invite) do
      {:ok, _invite} ->
        {:noreply,
         socket
         |> put_flash(:info, "Convite rejeitado.")
         |> push_navigate(to: ~p"/budgets")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Não foi possível rejeitar o convite.")
         |> push_navigate(to: ~p"/budgets")}
    end
  end

  @impl true
  def handle_event("accept_invite", _params, socket) do
    user = socket.assigns.current_scope.user
    invite = socket.assigns.invite

    case Finance.accept_budget_invite(invite, user) do
      {:ok, _invite} ->
        {:noreply,
         socket
         |> put_flash(:info, "Convite aceito com sucesso! Você agora é membro do orçamento.")
         |> push_navigate(to: ~p"/budgets/#{invite.budget_id}/home")}

      {:error, :invalid_invite} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Não foi possível aceitar o convite. Verifique se ele é válido para o seu e-mail ou se já não expirou."
         )
         |> push_navigate(to: ~p"/budgets")}

      # Outros erros internos
      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Ocorreu um erro ao aceitar o convite.")
         |> push_navigate(to: ~p"/budgets")}
    end
  end

  # Helpers
  defp handle_acceptance(socket, invite, user) do
    if invite.email == user.email do
      case Finance.accept_budget_invite(user, invite) do
        {:ok, _invite} ->
          {:ok,
           socket
           |> put_flash(:info, "Convite aceito com sucesso! Você agora é membro do orçamento.")
           |> push_navigate(to: ~p"/budgets/#{invite.budget_id}/home")}

        {:error, _reason} ->
          {:ok,
           socket
           |> put_flash(:error, "Não foi possível aceitar o convite. Por favor, tente novamente.")
           |> push_navigate(to: ~p"/budgets")}
      end
    else
      # O usuário logado não é o convidado
      {:ok,
       socket
       |> put_flash(
         :error,
         "Você está logado como um usuário diferente do convidado. Por favor, faça logout e entre com o e-mail de convite ou crie uma nova conta."
       )
       |> assign(invite: invite, page_title: "Convite de Orçamento", show_login_register: true)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen bg-gray-50 dark:bg-gray-900 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md w-full space-y-8 bg-white dark:bg-gray-800 p-8 rounded-lg shadow-md">
        <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900 dark:text-white">
          Aceitar Convite para Orçamento
        </h2>
        <%= if @show_login_register do %>
          <p class="mt-2 text-center text-sm text-gray-600 dark:text-gray-400">
            Para aceitar o convite para o orçamento "{@invite.budget.name}", por favor, faça login ou crie uma conta usando o e-mail:
            <span class="font-bold text-blue-600">{@invite.email}</span>
          </p>
          <div class="mt-8 space-y-6">
            <.link
              navigate={~p"/users/log-in"}
              class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Fazer Login
            </.link>
            <.link
              navigate={~p"/users/register"}
              class="mt-3 group relative w-full flex justify-center py-2 px-4 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 dark:bg-gray-700 dark:text-gray-200 dark:border-gray-600 dark:hover:bg-gray-600"
            >
              Criar Conta
            </.link>
          </div>
        <% else %>
          <p class="mt-2 text-center text-lg text-gray-800 dark:text-gray-200">
            Você foi convidado para o orçamento: <span class="font-bold">{@invite.budget.name}</span>
          </p>
          <p class="text-center text-sm text-gray-600 dark:text-gray-400">
            Convidado por: {@invite.inviter.email}
          </p>
          <button
            phx-click="accept_invite"
            class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
          >
            Aceitar Convite
          </button>
          <button
            phx-click="reject_invite"
            class="mt-3 group relative w-full flex justify-center py-2 px-4 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 dark:bg-gray-700 dark:text-gray-200 dark:border-gray-600 dark:hover:bg-gray-600"
          >
            Rejeitar Convite
          </button>
        <% end %>
      </div>
    </div>
    """
  end
end
