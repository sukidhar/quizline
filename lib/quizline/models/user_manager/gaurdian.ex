defmodule Quizline.UserManager.Guardian do
  use Guardian, otp_app: :quizline

  alias Quizline.UserManager

  def subject_for_token(data, _claims) do
    {:ok, to_string(data.id)}
  end

  def resource_from_claims(%{"sub" => id}) do
    IO.inspect(id)
    UserManager.get_user_by_id(id)
  rescue
    e ->
      IO.inspect(e)
      {:error, :resource_not_found}
  end
end
