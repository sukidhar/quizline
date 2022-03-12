defmodule Quizline.UserManager.ErrorHandler do
  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, reason}, _opts) do
    IO.inspect(type)
    IO.inspect(reason)
    Phoenix.Controller.redirect(conn, to: "/auth")
  end
end
