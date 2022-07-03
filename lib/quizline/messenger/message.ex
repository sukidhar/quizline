defmodule Quizline.Messenger.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :attachment, :string
    field :content, :string
    field :sender, Ecto.Enum, values: [:student, :invigilator, :admin]
    field :chat_id, :id

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :attachment, :sender])
    |> validate_required([:content, :attachment, :sender])
  end
end
