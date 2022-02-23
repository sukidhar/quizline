defmodule Quizline.AdminManager do
  import Necto
  alias Quizline.AdminManager.Admin

  def create_user(attrs \\ %{}) do
    %Admin{}
    |> Admin.registration_changeset(attrs)
    |> create(:admin)
  end

  def registration_change_admin(%Admin{} = admin, attrs \\ %{}) do
    Admin.registration_changeset(admin, attrs)
  end
end
