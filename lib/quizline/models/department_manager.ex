defmodule Quizline.DepartmentManager do
  alias Necto
  # alias Quizline.DepartmentManager.Branch
  import Necto.ErrorHandler
  alias Quizline.DepartmentManager.Department
  alias Ecto.Changeset

  def create_department(%Changeset{valid?: true, changes: data}, id) do
    case Necto.create_department(data, id) do
      {:ok, dep} ->
        {:ok, dep}

      {:error, %Bolt.Sips.Exception{} = neoex} ->
        handle_exception(neoex)

      {:error, reason} ->
        {:error, "unknown error occured"}
    end
  end

  def create_department(%Changeset{valid?: false}, _id) do
    {:error, "please make sure valid fields are filled"}
  end

  def create_departments(data, id) do
    data
    |> Enum.map(fn [title, email] ->
      department_changeset(%Department{}, %{title: title, email: email})
    end)
    |> Enum.reject(fn %Changeset{valid?: valid} ->
      not valid
    end)
    |> Enum.map(fn %Changeset{changes: data} ->
      data
    end)
    |> Necto.create_departments(id)
    |> case do
      {:ok, deps} ->
        {:ok, deps}

      {:error, %Bolt.Sips.Exception{} = neoex} ->
        handle_exception(neoex)

      {:error, reason} ->
        {:error, "unknown error occured"}
    end
  end

  def department_changeset(%Department{} = department, params \\ %{}) do
    Department.changeset(department, params)
  end

  def branch_changeset(%Department.Branch{} = branch, params \\ %{}) do
    Department.branch_changeset(branch, params)
  end

  def create_branch(%Changeset{valid?: true, changes: changes}, department_email) do
    Necto.create_branch(%{
      title: changes.title,
      branch_id: changes.branch_id,
      id: changes.id,
      email: department_email
    })
  end

  def create_branch(%Changeset{valid?: false}, _) do
    {:error, "please make sure valid fields are filled"}
    |> IO.inspect()
  end

  def delete_branch(id) do
    case Necto.delete_branch(id) do
      {:ok, _} ->
        {:ok, "deleted branch succesfully"}

      {:error, reason, e} ->
        IO.inspect(e)

        {:error, reason}
    end
  end

  def get_departments_with_branches(page \\ 0, id) do
    {:ok, departments} = Necto.get_departments(page, id)
    {:ok, departments}
  end
end
