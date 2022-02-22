defmodule Quizline.AdminManager.Guardian do
  use Guardian, otp_app: :quizline

  # alias Quizline.AdminManager

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  @spec resource_from_claims(map) :: {:error, :resource_not_found} | {:ok, any}
  def resource_from_claims(%{"sub" => id}) do
    # user = AdminManager.get_user!(id)
    {:ok, %{id: id}}
    # rescue
    #   Ecto.NoResultsError -> {:error, :resource_not_found}
  end
end
