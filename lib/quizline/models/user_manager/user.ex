defmodule Quizline.UserManager.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ecto.Changeset

  embedded_schema do
    field(:reg_no, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
    field(:password, :string)
    field(:confirm_password, :string)
    field(:hashed_password, :string)
    field(:account_type, Ecto.Enum, values: [:invigilator, :student])
    field(:created_at, :string)
  end

  def changeset(user, params) do
    user
    |> cast(params, [:reg_no, :first_name, :last_name, :email, :account_type])
    |> validate_required([:reg_no, :first_name, :last_name, :email, :account_type])
    |> put_change(:id, Ecto.UUID.generate())
  end

  def login_changeset(user, params) do
    user
    |> cast(params, [:email, :password])
    |> validate_required([:email, :password])
  end

  def password_changeset(user, params) do
    user
    |> cast(params, [:password, :confirm_password])
    |> validate_required([:password, :confirm_password])
    |> validate_format(:password, ~r/[0-9]+/, message: "Password must contain a number")
    |> validate_format(:password, ~r/[A-Z]+/,
      message: "Password must contain an upper-case letter"
    )
    |> validate_format(:password, ~r/[a-z]+/, message: "Password must contain a lower-case letter")
    |> validate_format(:password, ~r/[#\!\?&@\$%^&*\(\)]+/,
      message: "Password must contain a symbol"
    )
    |> hash_password()
  end

  defp hash_password(
         %Changeset{
           changes: %{password: password, confirm_password: confirm_password}
         } = changeset
       ) do
    if password === confirm_password do
      changeset
      |> put_change(:hashed_password, Argon2.hash_pwd_salt(password))
    else
      changeset
      |> add_error(:confirm_password, "passwords entered doesn't match")
    end
  end

  defp hash_password(changeset), do: changeset
end
