defmodule Quizline.AdminManager.AdminEmailer do
  import Swoosh.Email

  alias Quizline.Mailer

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Quizline", "sukidhar@gmail.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    else
      k -> IO.inspect(k)
    end
  end

  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """
    ==============================
    Hi #{user.email},
    You can confirm your account by visiting the URL below:
    #{url}
    If you didn't create an account with us, please ignore this.
    ==============================
    """)
  end

  def deliver_reset_instructions(user, url) do
    deliver(user.email, "Password recovery instructions", """
    ==============================
    Hi #{user.email},
    You can reset your account password by visiting the URL below:
    #{url}
    If you didn't require this instructions, please ignore this.
    ==============================
    """)
  end
end
