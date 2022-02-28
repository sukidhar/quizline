defmodule Quizline.AdminManager do
  import Necto
  alias Quizline.AdminManager.Admin
  import Ecto.Changeset

  def create_user(attrs \\ %{}) do
    %Admin{}
    |> Admin.registration_changeset(attrs)
    |> delete_change(:password)
    |> delete_change(:confirm_password)
    |> put_change(:created_at, "#{DateTime.to_unix(DateTime.utc_now())}")
    |> put_change(:id, Ecto.UUID.generate())
    |> create(:admin)
  end

  def registration_change_admin(%Admin{} = admin, attrs \\ %{}) do
    Admin.registration_changeset(admin, attrs)
  end
end
