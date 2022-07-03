defmodule Quizline.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :content, :string
      add :attachment, :string
      add :sender, :string
      add :chat_id, references(:chats, on_delete: :nothing)

      timestamps()
    end

    create index(:messages, [:chat_id])
  end
end
