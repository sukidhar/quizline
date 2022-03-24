defmodule Quizline.UserManager.Department do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:title, :string)
    field(:email, :string)
    field(:branch, :string)
    field(:created, :string)
    field(:updated, :string)
  end

  def changeset(department, params) do
    department
    |> cast(params, [:title, :email, :branch, :created, :updated])
    |> validate_required([:title, :email])
    |> requires_branch?(params)
  end

  def requires_branch?(changeset, %{account_type: account_type}) do
    case account_type do
      "student" -> changeset |> validate_required([:branch])
      _ -> changeset
    end
  end

  def requires_branch?(changeset, _) do
    changeset
  end
end
