defmodule PersonalFinanceWeb.Router do
  use PersonalFinanceWeb, :router

  import PersonalFinanceWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PersonalFinanceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks.
  # scope "/api", PersonalFinanceWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:personal_finance, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PersonalFinanceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PersonalFinanceWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PersonalFinanceWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/budgets", BudgetsLive.Index, :index
      live "/budgets/new", BudgetsLive.Index, :new
      live "/budgets/:id/edit", BudgetsLive.Index, :edit
      live "/budgets/:id/home", HomeLive.Index, :index
      live "/budgets/:id/profiles", ProfileLive.Index, :index
      live "/budgets/:id/profiles/new", ProfileLive.Index, :new
      live "/budgets/:id/profiles/:profile_id/edit", ProfileLive.Index, :edit
      live "/budgets/:id/transactions", TransactionLive.Index, :index
      live "/budgets/:id/transactions/new", TransactionLive.Index, :new
      live "/budgets/:id/transactions/:transaction_id/edit", TransactionLive.Index, :edit
      live "/budgets/:id/categories", CategoryLive.Index, :index
      live "/budgets/:id/categories/new", CategoryLive.Index, :new
      live "/budgets/:id/categories/:category_id/edit", CategoryLive.Index, :edit
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", PersonalFinanceWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{PersonalFinanceWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
