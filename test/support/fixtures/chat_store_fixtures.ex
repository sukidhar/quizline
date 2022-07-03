defmodule Quizline.ChatStoreFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Quizline.ChatStore` context.
  """

  @doc """
  Generate a chat.
  """
  def chat_fixture(attrs \\ %{}) do
    {:ok, chat} =
      attrs
      |> Enum.into(%{
        admin: "7488a646-e31f-11e4-aace-600308960662",
        invigilator: "7488a646-e31f-11e4-aace-600308960662",
        room: "7488a646-e31f-11e4-aace-600308960662",
        student: "7488a646-e31f-11e4-aace-600308960662",
        unseen: 42
      })
      |> Quizline.ChatStore.create_chat()

    chat
  end
end
