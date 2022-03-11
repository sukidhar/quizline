defmodule Quizline.UserManager.UserMailer do
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

  def deliver_password_settings(user, url) do
    deliver(user.email, "Password instructions", """
    ==============================
    Hi #{user.first_name},
    Your account has been created and to gain access to it.
    Please visit the URL below:
    #{url}
    ==============================
    """)
  end
end
