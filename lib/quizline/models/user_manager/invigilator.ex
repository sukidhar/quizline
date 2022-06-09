defmodule Quizline.UserManager.Invigilator do
  use Ecto.Schema
  import Ecto.Changeset
  import Quizline.ChangesetHelper

  # alias Ecto.Changeset

  embedded_schema do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
    field(:profile_pic, :string)
    field(:created_at, :string)
    field(:password, :string)
    field(:confirm_password, :string)
    field(:hashed_password, :string)

    embeds_one(:department, Quizline.DepartmentManager.Department)
  end

  def changeset(user, params) do
    user
    |> cast(params, [:first_name, :last_name, :email])
    |> cast_embed(:department,
      with: &Quizline.DepartmentManager.Department.changeset/2,
      required: true
    )
    |> validate_required([:first_name, :last_name, :email])
    |> validate_email()
    |> put_change(:id, Ecto.UUID.generate())
  end
end
