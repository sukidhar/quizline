defmodule Quizline.DepartmentManager do
  alias Necto
  alias Quizline.DepartmentManager.Branch
  alias Quizline.DepartmentManager.Department
  alias Ecto.Changeset

  def create_department(%Changeset{valid?: true, changes: data}, id) do
    {:ok, dep} = Necto.create_department(data, id)
    {:ok, dep}
  end

  def create_department(%Changeset{valid?: false}, _id) do
    {:error, "please make sure valid fields are filled"}
  end

  def department_changeset(%Department{} = department, params \\ %{}) do
    Department.changeset(department, params)
  end

  def branch_changeset(%Branch{} = branch, params \\ %{}) do
    Branch.changeset(branch, params)
  end
end
