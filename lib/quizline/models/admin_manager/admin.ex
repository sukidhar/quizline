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
    field(:uid, :string)
    field(:created_at, :string)
  end

  def registration_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:first_name, :last_name, :email, :password, :confirm_password])
    |> validate_required([:first_name, :last_name, :email, :password, :confirm_password])
    |> set_uuid()
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

  defp set_uuid(%Changeset{valid?: true} = changeset) do
    changeset
    |> put_change(:uid, Ecto.UUID.generate())
  end

  defp set_uuid(changeset), do: changeset

  defp validate_email(%Changeset{valid?: true, changes: %{email: email}} = changeset) do
    case EmailChecker.valid?(email) do
      true ->
        changeset

      false ->
        changeset |> add_error(:email, "invalid_format")
    end
  end

  defp validate_email(changeset), do: changeset

  defp hash_password(
         %Changeset{
           valid?: true,
           changes: %{password: password, confirm_password: confirm_password}
         } = changeset
       ) do
    if password === confirm_password do
      changeset
      |> put_change(:password, Argon2.hash_pwd_salt(password))
      |> delete_change(:confirm_password)
    else
      changeset
      |> add_error(:confirm_password, "passwords doesn't match")
    end
  end
end
