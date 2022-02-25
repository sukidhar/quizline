defmodule Necto do
  alias Ecto.Changeset

  def create(%Changeset{valid?: true} = changeset, label) do
    IO.inspect(changeset)
    IO.inspect(label)
    {:ok, %{}}
  end

  def create(%Changeset{valid?: false} = changeset, _label) do
    {:error, changeset}
  end
end
