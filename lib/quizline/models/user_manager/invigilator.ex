defmodule Quizline.UserManager.Invigilator do
  use Ecto.Schema
  import Ecto.Changeset
  import Quizline.ChangesetHelper

  alias Ecto.Changeset

  embedded_schema do
    field(:reg_no, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
    field(:profile_pic, :string)
    field(:created_at, :string)
    field(:password, :string)
    field(:confirm_password, :string)
    field(:hashed_password, :string)
  end

  def changeset(user, params) do
    user
    |> cast(params, [:reg_no, :first_name, :last_name, :email])
    |> validate_required([:reg_no, :first_name, :last_name, :email])
    |> put_change(:id, Ecto.UUID.generate())
  end
end
