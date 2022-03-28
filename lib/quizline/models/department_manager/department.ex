defmodule Quizline.DepartmentManager.Department do
  use Ecto.Schema
  import Ecto.Changeset
  import Quizline.ChangesetHelper
  alias Ecto.Changeset

  embedded_schema do
    field(:title, :string)
    field(:dep, :string)
    field(:email, :string)
    field(:created, :string)
    field(:updated, :string)
  end

  def changeset(department, params) do
    department
    |> cast(params, [:title, :dep, :email, :created, :updated])
    |> validate_required([:title, :email])
    |> update_change(:title, &String.trim/1)
    |> update_dep()
  end

  defp update_dep(%Changeset{changes: %{title: title}} = changeset) do
    changeset |> put_change(:dep, initalised_string(title))
  end

  defp update_dep(changeset) do
    changeset
  end
end
