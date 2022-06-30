defmodule Quizline.EventManager do
  alias Quizline.EventManager.Exam

  def exam_primary_changeset(%Exam{} = exam, params \\ %{}) do
    Exam.primary_changeset(exam, params)
  end

  def exam_secondary_changeset(%Exam{} = exam, params \\ %{}) do
    Exam.secondary_changeset(exam, params)
  end

  def qp_changeset(%Exam.QuestionPaper{} = qp, params \\ %{}) do
    Exam.qp_changeset(qp, params)
  end

  def create_exam(data, id) do
    Necto.create_exam_event(data, id)
    # ? schedule emails using oban
    :ok
  end

  def delete_exam(id) do
    Necto.delete_exam_event(id)
  end

  def create_exams(data, id) do
    Necto.create_multiple_exams(data, id)
    # ? schedule emails using oban
    :ok
  end

  def fetch_exams(id) do
    Necto.fetch_exam_events(id)
  end

  def get_event_details(id) do
    Necto.fetch_exam_event_details(id)
  end

  def get_room_details(id) do
    Necto.fetch_room_details(id)
  end

  def remove_student_from_room(sid, room_id) do
    Necto.remove_student_from_room(sid, room_id)
  end

  def add_student_to_room(sid, room_id) do
    Necto.add_student_to_room(sid, room_id)
  end

  def find_students(keyword, event_id) do
    Necto.get_students_fuzzy(keyword, event_id)
  end

  def get_events_for_user(id) do
    Necto.get_events_for_user(id)
  end

  def get_event(room_id) do
    Necto.get_event(room_id)
  end

  def fetch_question_papers(event) do
    Necto.fetch_question_papers(event)
  end
end
