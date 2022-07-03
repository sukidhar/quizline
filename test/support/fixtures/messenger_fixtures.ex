defmodule Quizline.MessengerFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Quizline.Messenger` context.
  """

  @doc """
  Generate a message.
  """
  def message_fixture(attrs \\ %{}) do
    {:ok, message} =
      attrs
      |> Enum.into(%{
        attachment: "some attachment",
        content: "some content",
        sender: :student
      })
      |> Quizline.Messenger.create_message()

    message
  end
end
