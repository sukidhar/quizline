defmodule QuizlineWeb.AdminAuthController do
  use QuizlineWeb, :controller

  alias Quizline.AdminManager
  alias Quizline.AdminManager.Guardian
  alias QuizlineWeb.Presence

  def verify(conn, %{"token" => token}) do
    with {:verify, {:ok, %{"sub" => id}}} <- {:verify, Guardian.decode_and_verify(token)} do
      with {:ok, _} <- AdminManager.verify_email(%AdminManager.Admin{id: id}) do
        Enum.map(Presence.list("auth")[id][:metas] || [], fn k ->
          Presence.update(k.pid, "auth", id, %{is_verified: true, pid: k.pid})
        end)

        text(conn, "request received with #{id}")
      else
        _ -> text(conn, "invalid token")
      end
    else
      _ -> text(conn, "error route")
    end
  end

  def authenticate(conn, %{"token" => token}) do
    IO.inspect(token)

    with {:verify, {:ok, admin, _}} <- {:verify, Guardian.resource_from_token(token)} do
      redirect(conn |> Guardian.Plug.sign_in(admin), to: "/")
    else
      {:verify, error} ->
        IO.inspect(error)
        text(conn, "unknown error")
    end
  end
end
