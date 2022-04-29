defmodule Quizline.SubjectManager.Subject do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  embedded_schema do
    field(:title, :string)
    field(:subject_code, :string)
    field(:created, :string)
    field(:updated, :string)

    embeds_many :associates, Associate do
      embeds_one(:semester, Quizline.SemesterManager.Semester)
      embeds_one(:branch, Quizline.DepartmentManager.Department.Branch)
    end
  end

  def changeset(subject, params) do
    subject
    |> cast(params, [:title, :subject_code])
    |> cast_embed(:associates, with: &associate_changeset/2)
    |> validate_required([:title, :subject_code])
  end

  def associate_changeset(association, params) do
    association
    |> cast(params, [:semester, :branch])
    |> add_id()
  end

  defp add_id(%Changeset{changes: %{id: _id}} = changeset) do
    changeset
  end

  defp add_id(changeset) do
    changeset |> put_change(:id, Ecto.UUID.generate())
  end
end
