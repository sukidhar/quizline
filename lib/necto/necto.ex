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
              |> structify_response(label, "no such node found")} do
        {:ok, data}
      else
        {:fetch, {:error, reason}} -> {:error, changeset, reason: reason}
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

  defp structify_response(response, label, error) do
    case %{label: label, modules: Application.get_env(:quizline, Necto)[:modules]} do
      %{label: :admin, modules: %{admin: struct}} ->
        data =
          Enum.map(response.results, fn res ->
            Kernel.struct!(struct, convert_to_klist(res["n"].properties))
          end)

        case List.first(data) do
          nil -> {:error, error}
          data -> {:ok, data}
        end

      %{label: :user, modules: %{user: struct}} ->
        %{"n" => node, "r" => r} = response

        props =
          convert_to_klist(node.properties)
          |> Keyword.put(:account_type, String.downcase(hd(node.labels) || "student"))
          |> Keyword.put(
            :created_at,
            "#{r.properties["created_at"] || DateTime.to_unix(DateTime.utc_now())}"
          )

        {:ok, Kernel.struct!(struct, props)}

      _ ->
        {:error, "Struct Module not mentioned in config.exs"}
    end
  end

  defp convert_to_klist(map) do
    Enum.map(map, fn {key, value} -> {String.to_existing_atom(key), value} end)
  end

  def verify_admin(%Quizline.AdminManager.Admin{id: id}) do
    query =
      "MATCH (admin:Admin) WHERE admin.id='#{id}' SET admin.verified=true RETURN admin.verified AS response"

    conn = Sips.conn()

    try do
      _ = Sips.query!(conn, query)
      {:ok, true}
    rescue
      e -> {:error, e}
    end
  end

  def get_admin(:email, email) do
    query = "MATCH (n : Admin) WHERE n.email='#{email}' RETURN n"

    conn = Sips.conn()

    try do
      with {:fetch, {:ok, data}} <-
             {:fetch,
              Sips.query!(conn, query)
              |> structify_response(:admin, "no such admin found")} do
        {:ok, data}
      else
        {:fetch, {:error, reason}} ->
          {:error, reason: reason}
      end
    rescue
      e ->
        {:error, e.message}
    end
  end

  def get_admin(:id, id) do
    query = "MATCH (n : Admin) WHERE n.id='#{id}' RETURN n"

    conn = Sips.conn()

    try do
      with {:fetch, {:ok, data}} <-
             {:fetch,
              Sips.query!(conn, query)
              |> structify_response(:admin, "no such admin found")} do
        {:ok, data}
      else
        {:fetch, {:error, reason}} ->
          {:error, reason: reason}
      end
    rescue
      e -> {:error, reason: e.message}
    end
  end

  def update_admin_password(id, password) do
    query =
      "MATCH (n: Admin) WHERE n.id = '#{id}' SET n += { hashed_password: '#{password}', verified: true } RETURN n.verified"

    conn = Sips.conn()

    try do
      _ = Sips.query!(conn, query)
      {:ok, true}
    rescue
      e -> {:error, e}
    end
  end

  def create_user_accounts(changesets, id) do
    query = """
    UNWIND $batch as row
    CALL apoc.do.when(row.account_type = 'invigilator', 'MATCH (admin:Admin) WHERE admin.id = $id CREATE (n: Invigilator:User $row) <-[r:has_invigilator {created_at: datetime().epochSeconds}]-(admin) RETURN n,r', 'MATCH (admin:Admin) WHERE admin.id = $id CREATE (n: Student:User $row) <-[r:has_student {created_at: datetime().epochSeconds}]-(admin) RETURN n,r', {row: apoc.map.removeKey(row,"account_type"), id: $id}) YIELD value
    WITH value as results
    RETURN results
    """

    batch =
      Enum.filter(changesets, fn set ->
        %Changeset{valid?: value} = set
        value
      end)
      |> Enum.map(fn set ->
        %Changeset{changes: changes} = set
        changes
      end)

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: data} = Sips.query!(conn, query, %{batch: batch, id: id})

      users =
        Enum.map(data, fn %{"results" => res} ->
          {:ok, user} = structify_response(res, :user, "no such node found")
          user
        end)

      {:ok, users}
    rescue
      e -> {:error, e}
    end
  end

  def get_user(:id, id) do
    query = "MATCH (n : User) WHERE n.id='#{id}' RETURN n"

    conn = Sips.conn()

    try do
      with {:fetch, {:ok, data}} <-
             {:fetch,
              Sips.query!(conn, query)
              |> structify_response(:user, "no such user found")} do
        {:ok, data}
      else
        {:fetch, {:error, reason}} ->
          {:error, reason: reason}
      end
    rescue
      e -> {:error, reason: e.message}
    end
  end
end
