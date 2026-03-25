defmodule PredictionsWeb.Router do
  use PredictionsWeb, :router

  import PredictionsWeb.Plugs.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PredictionsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public routes
  scope "/", PredictionsWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/sign-in", SessionController, :new
    post "/sign-in", SessionController, :create
    delete "/sign-out", SessionController, :delete
  end

  # Protected routes for signed-in users
  # Must be inside browser scope so flash is fetched before on_mount redirects
  scope "/", PredictionsWeb do
    pipe_through :browser

    live_session :user_authenticated,
      on_mount: [{PredictionsWeb.Plugs.Auth, :ensure_authenticated}] do
      live "/dashboard", UserDashboardLive, :index
    end
  end

  # Protected routes for admin users
  # Must be inside browser scope so flash is fetched before on_mount redirects
  scope "/", PredictionsWeb do
    pipe_through :browser

    live_session :admin_authenticated, on_mount: [{PredictionsWeb.Plugs.Auth, :ensure_admin}] do
      live "/admin", AdminDashboardLive, :index
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:predictions, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PredictionsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
