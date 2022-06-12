defmodule Quizline.UserManager.Student do
  use Ecto.Schema
  import Ecto.Changeset
  import Quizline.ChangesetHelper

  embedded_schema do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
    field(:rid, :string)
    field(:profile_pic, :string)
    field(:created_at, :string)
    field(:password, :string)
    field(:confirm_password, :string)
    field(:hashed_password, :string)

    embeds_one(:semester, Quizline.SemesterManager.Semester)
    embeds_one(:branch, Quizline.DepartmentManager.Department.Branch)
  end

  def changeset(user, params) do
    user
    |> cast(params, [:rid, :first_name, :last_name, :email])
    |> cast_embed(:semester, with: &Quizline.SemesterManager.Semester.changeset/2, required: true)
    |> cast_embed(:branch, with: &Quizline.DepartmentManager.branch_changeset/2, required: true)
    |> validate_required([:rid, :first_name, :last_name, :email])
    |> validate_email()
    |> validate_length(:first_name, min: 2)
    |> validate_length(:last_name, min: 2)
    |> put_change(:id, Ecto.UUID.generate())
  end

  def file_changeset(user, params) do
    user
    |> cast(params, [:first_name, :last_name, :email, :rid])
    |> validate_required([:first_name, :last_name, :email, :rid])
    |> validate_email()
    |> validate_length(:first_name, min: 2)
    |> validate_length(:last_name, min: 2)
    |> put_change(:id, Ecto.UUID.generate())
  end
end
