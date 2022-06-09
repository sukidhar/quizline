defmodule Quizline.UserManager.Student do
  use Ecto.Schema
  import Ecto.Changeset

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
    |> put_change(:id, Ecto.UUID.generate())
  end
end
