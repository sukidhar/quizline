defmodule QuizlineWeb.Router do
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
    plug Quizline.UserManager.Pipeline
  end

  pipeline :ensure_auth do
    plug Guardian.Plug.EnsureAuthenticated
  end

  scope "/", QuizlineWeb do
    pipe_through [:browser, :auth]

    live "/exam/:room", User.Student.ExamRoomLive

    live "/exam/i/:room", User.Invigilator.ExamRoomLive

    live "/auth", User.AuthLive

    live "/set-pw/:token", User.PasswordLive

    get "/authenticate/:token", AuthController, :authenticate_user
    get "/signout", AuthController, :sign_out_user
  end

  scope "/", QuizlineWeb do
    pipe_through [:browser, :auth, :ensure_auth]

    live "/", User.SessionLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", QuizlineWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  # if Mix.env() in [:dev, :test] do
  #   import Phoenix.LiveDashboard.Router

  #   scope "/" do
  #     pipe_through :browser

  #     live_dashboard "/dashboard", metrics: QuizlineWeb.Telemetry
  #   end
  # end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
