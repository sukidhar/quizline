defmodule Quizline.AdminManager.Pipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :quizline,
    module: Quizline.AdminManager.Guardian,
    error_handler: Quizline.AdminManager.ErrorHandler

  plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
  plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
  plug Guardian.Plug.LoadResource, allow_blank: true
end
