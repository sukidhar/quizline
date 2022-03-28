defmodule Quizline.ChangesetHelper do
  import Ecto.Changeset
  alias Ecto.Changeset

  @ignore_list ["and"]

  def hash_password(
        %Changeset{
          changes: %{password: password, confirm_password: confirm_password}
        } = changeset
      ) do
    if password === confirm_password do
      changeset
      |> put_change(:hashed_password, Argon2.hash_pwd_salt(password))
    else
      changeset
      |> add_error(:confirm_password, "passwords entered doesn't match")
    end
  end

  def hash_password(changeset), do: changeset

  def validate_email(%Changeset{changes: %{email: email}} = changeset) do
    case EmailChecker.valid?(email) do
      true ->
        changeset

      false ->
        changeset |> add_error(:email, "please, ensure if the entered email is invalid")
    end
  end

  def validate_email(changeset), do: changeset

  def initalised_string(string) do
    string
    |> String.split()
    |> Enum.map(fn k ->
      if k not in @ignore_list, do: String.first(k), else: nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join()
    |> String.upcase()
  end
end
