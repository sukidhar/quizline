defmodule Quizline.UserManager.User do
  use Ecto.Schema
  import Ecto.Changeset

  # alias Ecto.Changeset

  embedded_schema do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
    field(:hashed_password, :string)
    field(:account_type, Ecto.Enum, values: [:invigilator, :student])
    field(:created_at, :string)
  end

  def changeset(user, params) do
    user
    |> cast(params, [:first_name, :last_name, :email, :account_type])
    |> validate_required([:first_name, :last_name, :email, :account_type])
    |> put_change(:id, Ecto.UUID.generate())
  end
end
