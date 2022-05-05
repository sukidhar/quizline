defmodule Quizline.UserManager.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Quizline.ChangesetHelper

  # alias Ecto.Changeset

  embedded_schema do
    field(:email, :string)
    field(:password, :string)
    field(:confirm_password, :string)
    field(:hashed_password, :string)
  end

  def login_changeset(user, params) do
    user
    |> cast(params, [:email, :password])
    |> validate_required([:email, :password])
  end

  def fp_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_email()
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
end
