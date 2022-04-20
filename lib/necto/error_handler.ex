defmodule Necto.ErrorHandler do
  alias Bolt.Sips.Exception

  def handle_exception(%Exception{code: code, message: message}) do
    case {code, message |> String.split()} do
      {"Neo.ClientError.Schema.ConstraintValidationFailed",
       [_, _, _, _, _, label, _, _, prop, _, value]} ->
        {:error,
         """
         #{clean_string(label)} with #{clean_string(prop)} as "#{clean_string_no_cap(value)}" already exists
         """}
    end
  end

  defp clean_string(string) do
    String.replace(string, ~r(`|'), "") |> String.capitalize()
  end

  defp clean_string_no_cap(string) do
    String.replace(string, ~r(`|'), "")
  end
end
