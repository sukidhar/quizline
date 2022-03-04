defmodule QuizlineWeb.AdminAuth.AdminSession do
  use QuizlineWeb, :live_view

  def mount(_params, %{"guardian_default_token" => token}, socket) do
    IO.inspect(Quizline.AdminManager.Guardian.resource_from_token(token))
    {:ok, socket}
  end
end
