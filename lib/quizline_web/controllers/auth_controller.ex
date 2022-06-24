defmodule QuizlineWeb.AuthController do
  use QuizlineWeb, :controller

  alias Quizline.AdminManager
  alias QuizlineWeb.Presence
  alias Quizline.UserManager

  def verify_admin(conn, %{"token" => token}) do
    with {:verify, {:ok, %{"sub" => id}}} <-
           {:verify, AdminManager.Guardian.decode_and_verify(token)} do
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

  def authenticate_admin(conn, %{"token" => token}) do
    IO.inspect(token)

    with {:verify, {:ok, admin, _}} <- {:verify, AdminManager.Guardian.resource_from_token(token)} do
      redirect(conn |> AdminManager.Guardian.Plug.sign_in(admin, %{deviceId: UUID.uuid4()}),
        to: "/"
      )
    else
      {:verify, error} ->
        IO.inspect(error)
        text(conn, "unknown error")
    end
  end

  def authenticate_user(conn, %{"token" => token}) do
    IO.inspect(token)

    with {:verify, {:ok, user, _}} <- {:verify, UserManager.Guardian.resource_from_token(token)} do
      redirect(conn |> UserManager.Guardian.Plug.sign_in(user, %{deviceId: UUID.uuid4()}), to: "/")
    else
      {:verify, error} ->
        IO.inspect(error)
        text(conn, "unknown error")
    end
  end

  def sign_out_admin(conn, _) do
    redirect(conn |> AdminManager.Guardian.Plug.sign_out(), to: "/")
  end

  def sign_out_user(conn, _) do
    redirect(conn |> AdminManager.Guardian.Plug.sign_out(), to: "/")
  end
end
