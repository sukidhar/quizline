defmodule Quizline.SemesterManager.Semester do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  embedded_schema do
    field(:title, :string)
    field(:symbol, :string)
    field(:common?, :boolean, default: false)
    field(:created, :string)
  end

  def changeset(semester, params) do
    semester
    |> cast(params, [:title, :symbol, :common?])
    |> validate_required([:title, :symbol, :common?])
    |> update_change(:title, &String.trim/1)
    |> update_change(:symbol, &String.trim/1)
    |> add_id()
  end

  defp add_id(%Changeset{changes: %{id: _id}} = changeset) do
    changeset
  end

  defp add_id(changeset) do
    changeset |> put_change(:id, Ecto.UUID.generate())
  end
end
