defmodule Quizline.UserManager do
  alias Quizline.UserManager.UserMailer
  alias Quizline.UserManager.User
  alias Quizline.UserManager.Guardian
  import Ecto.Changeset
  alias Ecto.Changeset
  import Necto

  def create_accounts(account_data, id) do
    [data | _] = account_data

    res =
      Enum.map(data, fn account ->
        registration_user_set(%User{}, account)
      end)
      |> Necto.create_user_accounts(id)

    case res do
      {:ok, users} ->
        users
        |> Enum.map(fn user ->
          UserMailer.deliver_password_settings(
            user,
            "http://lvh.me:4000/set-pw/#{tokenise_user(user)}"
          )
        end)

        {:ok, users}

      {:error, e} ->
        IO.inspect(e)
        {:error, "failed to create accounts"}
    end
  end

  def registration_user_set(%User{} = user, params \\ %{}) do
    User.changeset(user, params)
  end

  def get_user_by_id(id) do
    with {:ok, %User{} = user} <- get_user(:id, id) do
      {:ok, user}
    else
      {:error, _} -> {:error, reason: "email not registered"}
    end
  end

  def tokenise_user(%User{} = admin) do
    {:ok, token, _claims} = Guardian.encode_and_sign(admin)
    token
  end
end
