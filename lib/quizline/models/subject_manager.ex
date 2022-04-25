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

  def create_subjects(data, def_email) do
    rows =
      data
      |> Enum.map(fn k ->
        case k do
          %{title: title, code: code, email: email} ->
            {subject_changeset(%Subject{}, %{title: title, subject_code: code}),
             if(email == "", do: def_email, else: email)}

          %{title: title, code: code} ->
            {subject_changeset(%Subject{}, %{title: title, subject_code: code}), def_email}
        end
      end)

    Enum.all?(rows, fn {%Ecto.Changeset{valid?: valid}, _email} ->
      valid
    end)
    |> case do
      true ->
        Enum.map(rows, fn {%Ecto.Changeset{changes: data}, email} ->
          %{sub: data, email: email}
        end)
        |> Necto.create_subjects()

      false ->
        {:error, "data is corrupted, or missing"}
    end
  end
end
