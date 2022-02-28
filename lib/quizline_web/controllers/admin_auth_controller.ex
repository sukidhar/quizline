defmodule QuizlineWeb.AdminAuthController do
  use QuizlineWeb, :controller

  alias Quizline.AdminManager
  alias Quizline.AdminManager.Guardian
  alias QuizlineWeb.Presence

  def verify(conn, %{"token" => token}) do
    with {:verify, {:ok, %{"sub" => id}}} <- {:verify, Guardian.decode_and_verify(token)} do
      with {:ok, _} <- AdminManager.verify_email(%AdminManager.Admin{id: id}) do
        [head | _] = Presence.list("auth")[id][:metas]
        Presence.update(head.pid, "auth", id, %{is_verified: true, pid: head.pid})
        text(conn, "request received with #{id}")
      else
        _ -> text(conn, "invalid token")
      end
    else
      _ -> text(conn, "error route")
    end
  end
end
