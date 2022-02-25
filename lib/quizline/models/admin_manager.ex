defmodule Quizline.AdminManager do
  import Necto
  alias Quizline.AdminManager.Admin
  import Ecto.Changeset

  def create_user(attrs \\ %{}) do
    %Admin{}
    |> Admin.registration_changeset(attrs)
    |> delete_change(:password)
    |> delete_change(:confirm_password)
    |> create(:admin)
  end

  def registration_change_admin(%Admin{} = admin, attrs \\ %{}) do
    Admin.registration_changeset(admin, attrs)
  end
end
