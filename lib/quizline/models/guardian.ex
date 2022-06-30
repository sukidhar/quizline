defmodule Quizline.Guardian do
  use Guardian, otp_app: :quizline

  def subject_for_token(data, _claims) do
    {:ok, data}
  end

  def resource_from_claims(%{"sub" => data}) do
    data
  end
end
