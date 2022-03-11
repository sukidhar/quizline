defmodule Quizline.AdminManager do
  require Logger
  import Necto
  alias Quizline.AdminManager.Admin
  alias Quizline.AdminManager.Guardian
  alias Quizline.AdminManager.AdminEmailer
  import Ecto.Changeset

  def create_user(attrs \\ %{}) do
    %Admin{}
    |> Admin.registration_changeset(attrs)
    |> delete_change(:password)
    |> delete_change(:confirm_password)
    |> put_change(:created_at, "#{DateTime.to_unix(DateTime.utc_now())}")
    |> put_change(:id, Ecto.UUID.generate())
    |> create(:admin)
  end

  def registration_change_admin(%Admin{} = admin, attrs \\ %{}) do
    Admin.registration_changeset(admin, attrs)
  end

  def login_change_admin(%Admin{} = admin, attrs \\ %{}) do
    Admin.login_changeset(admin, attrs)
  end

  def fp_change_admin(%Admin{} = admin, attrs \\ %{}) do
    Admin.fp_changeset(admin, attrs)
  end

  def fpset_change_admin(%Admin{} = admin, attrs \\ %{}) do
    Admin.fpset_changeset(admin, attrs)
  end

  def generate_verification_token(%Admin{} = admin) do
    data = %{id: admin.id}
    {:ok, jwt, _claims} = Guardian.encode_and_sign(data)
    IO.inspect(jwt)
    jwt
  end

  def verify_email(%Admin{} = admin) do
    verify_admin(admin)
  end

  def authenticate_admin(admin_params) do
    changeset =
      %Admin{}
      |> Admin.login_changeset(admin_params)
      |> Map.put(:action, :validate)

    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{email: email, password: password}} ->
        with {:ok, %Admin{hashed_password: hash} = admin} <- get_admin(:email, email) do
          if Argon2.verify_pass(password, hash) do
            {:access, admin}
          else
            {:error, %{changeset: changeset, reason: "Invalid email or password"}}
          end
        else
          {:error, _} ->
            {:error, reason: "email not registered"}
        end

      %Ecto.Changeset{valid?: false} ->
        IO.inspect(changeset)
        {:error, %{changeset: changeset}}
    end
  end

  def tokenise_admin(%Admin{} = admin) do
    {:ok, token, _claims} = Guardian.encode_and_sign(admin)
    token
  end

  def get_admin_by_id(id) do
    with {:ok, %Admin{} = admin} <- get_admin(:id, id) do
      {:ok, admin}
    else
      {:error, _} -> {:error, reason: "email not registered"}
    end
  end

  def send_fp_instructions(%Ecto.Changeset{valid?: true, changes: %{email: email}}) do
    with {:ok, admin} <-
           get_admin(:email, email) do
      AdminEmailer.deliver_reset_instructions(
        admin,
        "http://lvh.me:4000/forgot-password/#{tokenise_admin(admin)}"
      )
    else
      _ -> Logger.info("No such email exists")
    end
  end

  def send_fp_instructions(%Ecto.Changeset{valid?: false}) do
    Logger.info("Invalid data")
  end

  def update_password(id, password) do
    update_admin_password(id, password)
  end
end
