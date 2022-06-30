defmodule QuizlineWeb.User.Incharge.InchargeLive do
  use QuizlineWeb, :live_view

  alias Quizline.Guardian
  alias Quizline.EventManager
  alias Quizline.EventManager.Exam.QuestionPaper

  def mount(%{"token" => token}, _, socket) do
    case Guardian.decode_and_verify(token) do
      {:ok, %{"sub" => %{"email" => email, "event" => event}}} ->
        case EventManager.fetch_question_papers(event) do
          {:error, e} ->
            {:ok, socket |> redirect(to: "/error")}

          exam ->
            {:ok,
             socket
             |> assign(:email, email)
             |> assign(:exam, exam)
             |> assign(
               :qp_changeset,
               EventManager.qp_changeset(%QuestionPaper{})
             )
             |> allow_upload(:question_paper,
               accept: ~w(.pdf .docx .txt .rtf),
               max_entries: 1,
               external: &presign_upload/2
             )}
        end

      _ ->
        {:ok, socket |> redirect(to: "/error")}
    end
  end

  def handle_event("qp-change", params, socket) do
    IO.inspect(params)
    {:noreply, socket}
  end

  def handle_event("qp-submit", params, socket) do
    IO.inspect(params)
    {:noreply, socket}
  end

  def presign_upload(entry, socket) do
    {:ok, %{}, socket}
  end
end
