defmodule Quizline.Repo.Migrations.CreateChats do
  use Ecto.Migration

  def change do
    create table(:chats) do
      add :room, :uuid
      add :student, :uuid
      add :invigilator, :uuid
      add :admin, :uuid
      add :unseen, :integer

      timestamps()
    end
  end
end
