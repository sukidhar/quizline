defmodule Quizline.AdminManager.ErrorHandler do
  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {_type, _reason}, _opts) do
    IO.inspect("invoked")
    Phoenix.Controller.redirect(conn, to: "/auth")
  end
end
