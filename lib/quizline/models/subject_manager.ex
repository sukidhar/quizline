defmodule Quizline.SubjectManager do
  alias Quizline.SubjectManager.Subject
  alias Quizline.SubjectManager.Subject.Associate

  def subject_changeset(%Subject{} = subject, params \\ %{}) do
    Subject.changeset(subject, params)
  end

  def associate_changeset(%Associate{} = assoc, params \\ %{}) do
    Subject.associate_changeset(assoc, params)
  end

  def create_subject(%Ecto.Changeset{valid?: true, changes: params}, dep_email) do
    Necto.create_subject(params, dep_email)
  end

  def create_subject(%Ecto.Changeset{valid?: false} = changeset, _) do
    {:error, changeset}
  end

  def get_subjects(dep_email) do
    Necto.get_subjects(dep_email)
  end
end
