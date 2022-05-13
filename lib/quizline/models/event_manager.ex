defmodule Quizline.EventManager do
  alias Quizline.EventManager.Exam

  def exam_primary_changeset(%Exam{} = exam, params \\ %{}) do
    Exam.primary_changeset(exam, params)
  end

  def exam_secondary_changeset(%Exam{} = exam, params \\ %{}) do
    Exam.secondary_changeset(exam, params)
  end

  def create_exam(data, id) do
    Necto.create_exam_event(data, id)
  end

  def create_exams(data, id) do
    Necto.create_multiple_exams(data, id)
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
end
