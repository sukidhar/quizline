defmodule Quizline.DepartmentManager.Branch do
  use Ecto.Schema

  import Ecto.Changeset
  # alias Ecto.Changeset

  embedded_schema do
    field(:title, :string)
  end

  def changeset(branch, params) do
    branch
    |> cast(params, [:title, :id])
    |> validate_required([:title, :id])
    |> put_change(:id, Ecto.UUID.generate())
  end
end
