defmodule QuizlineWeb.PageController do
  use QuizlineWeb, :controller

  def index(conn, _params) do
    text(conn, "Subdomain home page")
  end
end
