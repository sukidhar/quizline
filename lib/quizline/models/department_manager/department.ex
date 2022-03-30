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

    embeds_many :branches, Branch do
      field(:title, :string)
      field(:branch_id, :string)
    end
  end

  def changeset(department, params) do
    department
    |> cast(params, [:title, :dep, :email, :created, :updated])
    |> cast_embed(:branches, with: &branch_changeset/2)
    |> validate_required([:title, :email])
    |> update_change(:title, &String.trim/1)
    |> update_dep()
  rescue
    e ->
      IO.inspect(e)
  end

  defp update_dep(%Changeset{changes: %{title: title}} = changeset) do
    changeset |> put_change(:dep, initalised_string(title))
  end

  defp update_dep(changeset) do
    changeset
  end

  def branch_changeset(branch, params) do
    branch
    |> cast(params, [:title])
    |> validate_required([:title])
    |> update_branch_id()
    |> add_id()
  end

  defp update_branch_id(%Changeset{changes: %{title: title}} = changeset) do
    changeset |> put_change(:branch_id, initalised_string(title))
  end

  defp update_branch_id(changeset) do
    changeset
  end

  defp add_id(%Changeset{changes: %{id: _id}} = changeset) do
    changeset
  end

  defp add_id(changeset) do
    changeset |> put_change(:id, Ecto.UUID.generate())
  end
end
