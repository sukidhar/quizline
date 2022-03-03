defmodule Quizline.AdminManager.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ecto.Changeset

  embedded_schema do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
    field(:password, :string)
    field(:confirm_password, :string)
    field(:created_at, :string)
    field(:hashed_password, :string)
    field(:verified, :boolean, default: false)
  end

  def login_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
  end

  def registration_changeset(admin, attrs) do
    admin
    |> cast(attrs, [
      :first_name,
      :last_name,
      :email,
      :password,
      :confirm_password,
      :hashed_password,
      :verified
    ])
    |> validate_required([:first_name, :last_name, :email, :password, :confirm_password])
    |> update_change(:email, &String.downcase/1)
    |> validate_email()
    |> validate_length(:password, min: 8)
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

  defp validate_email(%Changeset{changes: %{email: email}} = changeset) do
    case EmailChecker.valid?(email) do
      true ->
        changeset

      false ->
        changeset |> add_error(:email, "please, ensure if the entered email is invalid")
    end
  end

  defp validate_email(changeset), do: changeset

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
