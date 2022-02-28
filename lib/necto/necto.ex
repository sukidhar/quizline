defmodule Necto do
  alias Ecto.Changeset
  alias Bolt.Sips

  def create(%Changeset{valid?: true, changes: fields} = changeset, label) do
    query =
      "CREATE (n:#{String.capitalize(Atom.to_string(label))}) SET #{format_data(fields)} RETURN n"

    conn = Sips.conn()

    try do
      with {:fetch, {:ok, data}} <-
             {:fetch,
              Sips.query!(conn, query)
              |> structify_response(label)} do
        {:ok, data}
      else
        {:fetch, {:error, reason}} -> {:error, changeset, [reason: reason]}
      end
    rescue
      e -> {:error, e.message}
    end
  end

  def create(%Changeset{valid?: false} = changeset, _label) do
    {:error, changeset}
  end

  defp format_data(fields) do
    fields
    |> Enum.map(fn {k, v} -> "n.#{k} = '#{v}'" end)
    |> Enum.join(", ")
  end

  defp structify_response(response, label) do
    with {:fetch, [{^label, struct}]} <- {:fetch, Application.get_env(:quizline, Necto)[:modules]} do
      data =
        Enum.map(response.results, fn res ->
          Kernel.struct!(struct, convert_to_klist(res["n"].properties))
        end)

      {:ok, List.first(data) || Kernel.struct!(struct, [])}
    else
      {:fetch, _} -> {:error, "Struct Module not mentioned in config.exs"}
    end
  end

  defp convert_to_klist(map) do
    Enum.map(map, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end
end
