defmodule Quizline.UserManager.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Quizline.ChangesetHelper

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
    field(:semester, :string)
    field(:created_at, :string)
  end

  def changeset(user, params) do
    user
    |> cast(params, [:reg_no, :first_name, :last_name, :email, :account_type, :semester])
    |> validate_required([:reg_no, :first_name, :last_name, :email, :account_type])
    |> requires_semester?()
    |> put_change(:id, Ecto.UUID.generate())
  end

  defp requires_semester?(
         %Changeset{valid?: true, changes: %{account_type: account_type}} = changeset
       ) do
    if account_type == "student" do
      changeset |> validate_required([:semester])
    else
      changeset
    end
  end

  defp requires_semester?(changeset) do
    changeset
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
