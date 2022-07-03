defmodule Quizline.ChatStoreTest do
  use Quizline.DataCase

  alias Quizline.ChatStore

  describe "chats" do
    alias Quizline.ChatStore.Chat

    import Quizline.ChatStoreFixtures

    @invalid_attrs %{admin: nil, invigilator: nil, room: nil, student: nil, unseen: nil}

    test "list_chats/0 returns all chats" do
      chat = chat_fixture()
      assert ChatStore.list_chats() == [chat]
    end

    test "get_chat!/1 returns the chat with given id" do
      chat = chat_fixture()
      assert ChatStore.get_chat!(chat.id) == chat
    end

    test "create_chat/1 with valid data creates a chat" do
      valid_attrs = %{admin: "7488a646-e31f-11e4-aace-600308960662", invigilator: "7488a646-e31f-11e4-aace-600308960662", room: "7488a646-e31f-11e4-aace-600308960662", student: "7488a646-e31f-11e4-aace-600308960662", unseen: 42}

      assert {:ok, %Chat{} = chat} = ChatStore.create_chat(valid_attrs)
      assert chat.admin == "7488a646-e31f-11e4-aace-600308960662"
      assert chat.invigilator == "7488a646-e31f-11e4-aace-600308960662"
      assert chat.room == "7488a646-e31f-11e4-aace-600308960662"
      assert chat.student == "7488a646-e31f-11e4-aace-600308960662"
      assert chat.unseen == 42
    end

    test "create_chat/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ChatStore.create_chat(@invalid_attrs)
    end

    test "update_chat/2 with valid data updates the chat" do
      chat = chat_fixture()
      update_attrs = %{admin: "7488a646-e31f-11e4-aace-600308960668", invigilator: "7488a646-e31f-11e4-aace-600308960668", room: "7488a646-e31f-11e4-aace-600308960668", student: "7488a646-e31f-11e4-aace-600308960668", unseen: 43}

      assert {:ok, %Chat{} = chat} = ChatStore.update_chat(chat, update_attrs)
      assert chat.admin == "7488a646-e31f-11e4-aace-600308960668"
      assert chat.invigilator == "7488a646-e31f-11e4-aace-600308960668"
      assert chat.room == "7488a646-e31f-11e4-aace-600308960668"
      assert chat.student == "7488a646-e31f-11e4-aace-600308960668"
      assert chat.unseen == 43
    end

    test "update_chat/2 with invalid data returns error changeset" do
      chat = chat_fixture()
      assert {:error, %Ecto.Changeset{}} = ChatStore.update_chat(chat, @invalid_attrs)
      assert chat == ChatStore.get_chat!(chat.id)
    end

    test "delete_chat/1 deletes the chat" do
      chat = chat_fixture()
      assert {:ok, %Chat{}} = ChatStore.delete_chat(chat)
      assert_raise Ecto.NoResultsError, fn -> ChatStore.get_chat!(chat.id) end
    end

    test "change_chat/1 returns a chat changeset" do
      chat = chat_fixture()
      assert %Ecto.Changeset{} = ChatStore.change_chat(chat)
    end
  end
end
