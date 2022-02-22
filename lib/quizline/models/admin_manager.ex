defmodule Quizline.AdminManager do
  import Necto
  alias Quizline.AdminManager.Admin

  def create_user(attrs \\ %{}) do
    %Admin{}
    |> Admin.registration_changeset(attrs)
    |> create(:admin)
  end
end
