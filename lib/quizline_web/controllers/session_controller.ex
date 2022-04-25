defmodule QuizlineWeb.SessionController do
  use QuizlineWeb, :controller

  def get_departments_sample(conn, _params) do
    path = Application.app_dir(:quizline, "priv/static/sample_sheets/departments_sample.csv")
    send_download(conn, {:file, path})
  end

  def get_department_details_sample(conn, _params) do
    path =
      Application.app_dir(:quizline, "priv/static/sample_sheets/departments_details_sample.csv")

    send_download(conn, {:file, path})
  end
end
