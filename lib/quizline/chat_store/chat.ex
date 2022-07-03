defmodule Quizline.ChatStore.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chats" do
    field :admin, Ecto.UUID
    field :invigilator, Ecto.UUID
    field :room, Ecto.UUID
    field :student, Ecto.UUID
    field :unseen, :integer

    timestamps()
  end

  @doc false
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:room, :student, :invigilator, :admin, :unseen])
    |> validate_required([:room, :student, :invigilator, :admin, :unseen])
  end
end
