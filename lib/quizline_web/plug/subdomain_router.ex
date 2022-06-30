defmodule QuizlineWeb.SubdomainRouter do
  use QuizlineWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {QuizlineWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :auth do
    plug(Quizline.AdminManager.Pipeline)
  end

  pipeline :ensure_auth do
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  scope "/", QuizlineWeb do
    pipe_through([:browser, :auth])

    live("/auth", Admin.AuthLive)

    get("/verify/:token", AuthController, :verify_admin)
    get("/authenticate/:token", AuthController, :authenticate_admin)
    get("/signout", AuthController, :sign_out_admin)

    live("/forgot-password/:token", Admin.FPLive)

    get("/file/departments_template", SessionController, :get_departments_sample)
    get("/file/department_details_template", SessionController, :get_department_details_sample)
    get("/file/events_template", SessionController, :get_events_sample)
    get("/file/users_template", SessionController, :get_users_sample)

    live "/qpm/:token", User.Incharge.InchargeLive
  end

  import Phoenix.LiveDashboard.Router

  scope "/", QuizlineWeb do
    pipe_through([:browser, :auth, :ensure_auth])

    live("/", Admin.SessionLive)
    live_dashboard "/dashboard", metrics: QuizlineWeb.Telemetry
  end

  # Other scopes may use custom stacks.
  # scope "/api", Subdomainer do
  #   pipe_through :api
  # end
end
