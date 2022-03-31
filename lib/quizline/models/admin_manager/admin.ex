defmodule Quizline.AdminManager.Admin do
  use Ecto.Schema
  import Ecto.Changeset
  import Quizline.ChangesetHelper

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

  def fp_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_email()
  end

  def fpset_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:password, :confirm_password])
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
end
