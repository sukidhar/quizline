defmodule Quizline.SemesterManager do
  alias Quizline.SemesterManager.Semester

  def semester_changeset(%Semester{} = semester, params \\ %{}) do
    Semester.changeset(semester, params)
  end

  def create_semester(%Semester{} = semester, id) do
    Necto.create_semester(semester, id)
  end

  def get_semesters(id) do
    Necto.get_semesters(id)
  end
end
