defmodule Quizline.EventManager.Exam do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ecto.Changeset

  embedded_schema do
    field(:exam_group, :string)
    field(:date, :date)
    field(:start_time, :time)
    field(:end_time, :time)
    embeds_one(:subject, Quizline.SubjectManager.Subject)

    embeds_many :attendees, Attendee do
      embeds_one(:branch, Quizline.DepartmentManager.Department.Branch)
      embeds_one(:semester, Quizline.SemesterManager.Semester)
      field(:assigned, :boolean, default: true)
    end
  end

  def primary_changeset(exam, params) do
    exam
    |> cast(params, [:exam_group, :date, :start_time, :end_time])
    |> validate_required([:exam_group, :date, :start_time, :end_time])
    |> validate_date()
  end

  def secondary_changeset(exam, params) do
    exam
    |> cast(params, [])
    |> cast_embed(:subject, with: &Quizline.SubjectManager.Subject.changeset/2, required: true)
    |> cast_embed(:attendees, with: &attendee_changeset/2, required: true)
  end

  def validate_date(%Changeset{valid?: true, changes: %{date: date}} = changeset) do
    Date.compare(Date.utc_today(), date)
    |> case do
      x when x in [:gt, :eq] ->
        changeset |> add_error(:date, "exam date can't be today or in the past")

      _ ->
        changeset
    end
  end

  def validate_date(%Changeset{valid?: false} = changeset) do
    changeset
  end

  def attendee_changeset(attendee, params) do
    attendee
    |> cast(params, [:assigned])
    |> cast_embed(:branch,
      with: &Quizline.DepartmentManager.Department.branch_changeset/2,
      required: true
    )
    |> cast_embed(:semester,
      with: &Quizline.SemesterManager.Semester.changeset/2,
      required: true
    )
    |> validate_required([:assigned])
  end
end
