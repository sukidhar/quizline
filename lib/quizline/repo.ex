defmodule Quizline.Repo do
  use Ecto.Repo,
    otp_app: :quizline,
    adapter: Ecto.Adapters.Postgres
end
