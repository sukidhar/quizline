defmodule QuizlineWeb.SubdomainRouter do
  use QuizlineWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {QuizlineWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug Quizline.AdminManager.Pipeline
  end

  pipeline :ensure_auth do
    plug Guardian.Plug.EnsureAuthenticated
  end

  scope "/", QuizlineWeb do
    pipe_through [:browser, :auth]

    live "/auth", AdminAuth.AuthLive

    get "/verify/:token", AdminAuthController, :verify
    get "/authenticate/:token", AdminAuthController, :authenticate

    live "/forgot-password/:token", AdminAuth.FPLive
  end

  scope "/", QuizlineWeb do
    pipe_through [:browser, :auth, :ensure_auth]

    live "/", AdminAuth.AdminSession
  end

  # Other scopes may use custom stacks.
  # scope "/api", Subdomainer do
  #   pipe_through :api
  # end
end
