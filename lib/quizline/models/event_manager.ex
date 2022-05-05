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
end
