defmodule Quizline.UserManager do
  alias Quizline.UserManager.UserMailer
  alias Quizline.UserManager.Invigilator
  alias Quizline.UserManager.Student
  alias Quizline.UserManager.User
  alias Quizline.UserManager.Guardian
  import Necto

  require Logger

  alias Ecto.Changeset

  # def create_accounts(account_data, id) do
  #   [data | _] = account_data

  #   res =
  #     Enum.map(data, fn account ->
  #       %{
  #         user: registration_user_set(%User{}, account.user)
  #       }
  #     end)
  #     |> Necto.create_user_accounts(id)

  #   IO.inspect(res)

  #   case res do
  #     {:ok, users} ->
  #       users
  #       |> Enum.map(fn user ->
  #         UserMailer.deliver_password_settings(
  #           user,
  #           "http://lvh.me:4000/set-pw/#{tokenise_user(user)}"
  #         )
  #       end)

  #       {:ok, users}

  #     {:error, e} ->
  #       IO.inspect(e)
  #       {:error, "failed to create accounts"}
  #   end
  # end

  def registration_user_set(a, params \\ %{})

  def registration_user_set(:invigilator, params) do
    Invigilator.changeset(%Invigilator{}, params)
  end

  def registration_user_set(:student, params) do
    Student.changeset(%Student{}, params)
  end

  def fp_change_user(%User{} = user, attrs \\ %{}) do
    User.fp_changeset(user, attrs)
  end

  def login_user_set(%User{} = user, params \\ %{}) do
    User.login_changeset(user, params)
  end

  def password_user_set(%User{} = user, params \\ %{}) do
    User.password_changeset(user, params)
  end

  def get_user_by_id(id) do
    with {:ok, %User{} = user} <- get_user(:id, id) do
      {:ok, user}
    else
      {:error, _} -> {:error, reason: "email not registered"}
    end
  end

  def get_user_by_email(email) do
    with {:ok, %User{} = user} <- get_user(:email, email) do
      {:ok, user}
    else
      {:error, _} -> {:error, reason: "email not registered"}
    end
  end

  def authenticate_user(user_params) do
    changeset =
      %User{}
      |> login_user_set(user_params)
      |> Map.put(:action, :validate)

    case changeset do
      %Changeset{valid?: true, changes: %{email: email, password: password}} ->
        with {:ok, %User{hashed_password: hash} = user} <- get_user(:email, email) do
          if Argon2.verify_pass(password, hash) do
            {:access, user}
          else
            {:error, %{changeset: changeset, reason: "Invalid email or password"}}
          end
        else
          {:error, _} ->
            {:error, reason: "email not registered"}
        end

      %Changeset{valid?: false} ->
        {:error, %{changeset: changeset}}
    end
  end

  def tokenise_user(%User{} = user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    token
  end

  def update_password(id, password) do
    update_user_password(id, password)
  end

  def send_fp_instructions(%Ecto.Changeset{valid?: true, changes: %{email: email}}) do
    with {:ok, user} <-
           get_user(:email, email) do
      UserMailer.deliver_reset_instructions(
        user,
        "http://lvh.me:4000/set-pw/#{tokenise_user(user)}"
      )
    else
      _ -> Logger.info("No such email exists")
    end
  end

  def send_fp_instructions(%Ecto.Changeset{valid?: false}) do
    Logger.info("Invalid data")
  end
end
