defmodule Quizline.EventManager.Exam do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ecto.Changeset

  embedded_schema do
    field(:exam_group, :string)
    field(:date, :date)
    field(:start_time, :time)
    field(:end_time, :time)
    field(:uploader, :string)
    embeds_one(:subject, Quizline.SubjectManager.Subject)

    embeds_many :attendees, Attendee do
      embeds_one(:branch, Quizline.DepartmentManager.Department.Branch)
      embeds_one(:semester, Quizline.SemesterManager.Semester)
      field(:assigned, :boolean)
    end

    embeds_many :rooms, Room do
      embeds_one(:invigilator, Quizline.UserManager.Invigilator)
      embeds_many(:students, Quizline.UserManager.Student)
      field(:created, :string)
    end

    embeds_many :question_papers, QuestionPaper do
      field(:set, :string)
      field(:uploader, :string)
      field(:created, :string)
    end

    field(:created, :string)
    field(:updated, :string)
  end

  def primary_changeset(exam, params) do
    exam
    |> cast(params, [:exam_group, :date, :start_time, :end_time, :uploader])
    |> validate_required([:exam_group, :date, :start_time, :end_time, :uploader])
    |> validate_date()
    |> validate_time()
    |> Quizline.ChangesetHelper.add_id()
    |> validate_uploader()
  end

  def secondary_changeset(exam, params) do
    exam
    |> cast(params, [])
    |> cast_embed(:subject, with: &Quizline.SubjectManager.Subject.changeset/2, required: true)
    |> cast_embed(:attendees, with: &attendee_changeset/2, required: true)
    |> attendees_updated()
  end

  def qp_changeset(qp, params) do
    qp
    |> cast(params, [:set, :uploader, :created, :id])
    |> validate_required([:set, :uploader])
    |> Quizline.ChangesetHelper.add_id()
    |> validate_uploader()
  end

  def validate_uploader(%Changeset{valid?: true, changes: %{uploader: email}} = changeset) do
    case EmailChecker.valid?(email) do
      true ->
        changeset

      false ->
        changeset |> add_error(:uploader, "invalid email format or suspected temporary domain")
    end
  end

  def validate_uploader(changeset) do
    changeset
  end

  def validate_date(%Changeset{valid?: true, changes: %{date: date}} = changeset) do
    Date.compare(Date.utc_today(), date)
    |> case do
      x when x in [:gt] ->
        changeset |> add_error(:date, "exam date can't be today or in the past")

      _ ->
        changeset
    end
  end

  def validate_date(%Changeset{valid?: false} = changeset) do
    changeset
  end

  def validate_time(
        %Changeset{changes: %{start_time: start_time, end_time: end_time}} = changeset
      ) do
    case Time.compare(start_time, end_time) do
      :lt ->
        changeset

      _ ->
        changeset |> add_error(:end_time, "end time can not be in the past of start time")
    end
  end

  def validate_time(changeset) do
    changeset
  end

  def attendee_changeset(attendee, params) do
    attendee
    |> cast(params, [:assigned])
    |> cast_embed(:semester,
      with: &Quizline.SemesterManager.Semester.changeset/2,
      required: true
    )
    |> cast_embed(:branch,
      with: &Quizline.DepartmentManager.Department.branch_changeset/2,
      required: false
    )
    |> validate_required([:assigned])
  end

  def attendees_updated(%Changeset{valid?: true, changes: %{attendees: attendees}} = changeset) do
    is_valid =
      Enum.any?(attendees, fn k ->
        case k do
          %Changeset{valid?: true, changes: %{assigned: true}} -> true
          _ -> false
        end
      end)

    if is_valid do
      changeset
    else
      changeset |> add_error(:attendees, "atleast one group of attendees must be assigned")
    end
  end

  def attendees_updated(changeset) do
    changeset
  end
end
