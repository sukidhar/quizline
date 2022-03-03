defmodule Quizline.AdminManager.Guardian do
  use Guardian, otp_app: :quizline

  alias Quizline.AdminManager

  def subject_for_token(data, _claims) do
    {:ok, to_string(data.id)}
  end

  @spec resource_from_claims(map) :: {:error, :resource_not_found} | {:ok, any}
  def resource_from_claims(%{"sub" => id}) do
    AdminManager.get_admin_by_id(id)
  rescue
    _ -> {:error, :resource_not_found}
  end
end
