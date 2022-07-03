defmodule Quizline.MessengerTest do
  use Quizline.DataCase

  alias Quizline.Messenger

  describe "messages" do
    alias Quizline.Messenger.Message

    import Quizline.MessengerFixtures

    @invalid_attrs %{attachment: nil, content: nil, sender: nil}

    test "list_messages/0 returns all messages" do
      message = message_fixture()
      assert Messenger.list_messages() == [message]
    end

    test "get_message!/1 returns the message with given id" do
      message = message_fixture()
      assert Messenger.get_message!(message.id) == message
    end

    test "create_message/1 with valid data creates a message" do
      valid_attrs = %{attachment: "some attachment", content: "some content", sender: :student}

      assert {:ok, %Message{} = message} = Messenger.create_message(valid_attrs)
      assert message.attachment == "some attachment"
      assert message.content == "some content"
      assert message.sender == :student
    end

    test "create_message/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Messenger.create_message(@invalid_attrs)
    end

    test "update_message/2 with valid data updates the message" do
      message = message_fixture()
      update_attrs = %{attachment: "some updated attachment", content: "some updated content", sender: :invigilator}

      assert {:ok, %Message{} = message} = Messenger.update_message(message, update_attrs)
      assert message.attachment == "some updated attachment"
      assert message.content == "some updated content"
      assert message.sender == :invigilator
    end

    test "update_message/2 with invalid data returns error changeset" do
      message = message_fixture()
      assert {:error, %Ecto.Changeset{}} = Messenger.update_message(message, @invalid_attrs)
      assert message == Messenger.get_message!(message.id)
    end

    test "delete_message/1 deletes the message" do
      message = message_fixture()
      assert {:ok, %Message{}} = Messenger.delete_message(message)
      assert_raise Ecto.NoResultsError, fn -> Messenger.get_message!(message.id) end
    end

    test "change_message/1 returns a message changeset" do
      message = message_fixture()
      assert %Ecto.Changeset{} = Messenger.change_message(message)
    end
  end
end
