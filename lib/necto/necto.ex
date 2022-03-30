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
        case response do
          %{"n" => node, "r" => r} ->
            props =
              convert_to_klist(node.properties)
              |> Keyword.put(:account_type, String.downcase(hd(node.labels) || "student"))
              |> Keyword.put(
                :created_at,
                "#{r.properties["created_at"] || DateTime.to_unix(DateTime.utc_now())}"
              )

            {:ok, Kernel.struct!(struct, props)}

          %{"n" => node} ->
            props =
              convert_to_klist(node.properties)
              |> Keyword.put(:account_type, String.downcase(hd(node.labels) || "student"))

            {:ok, Kernel.struct!(struct, props)}
        end

      %{label: :department, modules: %{department: struct}} ->
        case response do
          %{"n" => node, "r" => r, "branches" => branch_nodes} ->
            branches =
              branch_nodes
              |> Enum.map(fn k ->
                props = convert_to_klist(k.properties)
                Kernel.struct!(Module.concat([struct, Branch]), props)
              end)

            props =
              convert_to_klist(node.properties)
              |> Keyword.put(
                :created,
                "#{r.properties["created"] || DateTime.to_unix(DateTime.utc_now())}"
              )
              |> Keyword.put(
                :updated,
                "#{r.properties["updated"]}"
              )
              |> Keyword.put(:branches, branches)

            {:ok, Kernel.struct!(struct, props)}

          %{"n" => node, "r" => r} ->
            props =
              convert_to_klist(node.properties)
              |> Keyword.put(
                :created,
                "#{r.properties["created"] || DateTime.to_unix(DateTime.utc_now())}"
              )
              |> Keyword.put(
                :updated,
                "#{r.properties["updated"]}"
              )

            {:ok, Kernel.struct!(struct, props)}
        end

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
    WITH row.user as userData, row.department as depData
    call apoc.do.when(
      userData.account_type="invigilator",
      "MERGE (n:Invigilator:User {email: user.email, first_name: user.first_name, last_name: user.last_name, reg_no: user.reg_no})
      ON CREATE SET n.id = user.id
      RETURN n",
      "MERGE (n:Student:User {email: user.email, first_name: user.first_name, last_name: user.last_name, reg_no: user.reg_no})
      ON CREATE SET n.id = user.id
      RETURN n",
      {user: apoc.map.removeKey(userData, "account_type")}
    ) YIELD value
    with value.n as user,userData, depData
    MATCH (admin:Admin {id: $id})
    MERGE (admin)-[r1:has_department]->(dep:Department {email: depData.email})
    ON CREATE SET r1.created = datetime().epochSeconds,
    dep.title = depData.title
    ON MATCH SET r1.updated = datetime().epochSeconds
    with admin, user, dep,userData, depData
    CALL apoc.do.when(
      userData.account_type = "invigilator",
      "MERGE (dep)-[r2:has_invigilator]->(user) ON CREATE SET r2.created = datetime().epochSeconds ON MATCH SET r2.updated = datetime().epochSeconds RETURN r2 as r",
      "
      MERGE (admin)-[k:has_semester]->(sem:Semester {title: br.semester}) ON CREATE SET k.created = datetime().epochSeconds ON MEATCH SET k.updated = datetime().epochSeconds
      MERGE (dep)-[r2:has_branch]->(branch:Branch {title: br.title}) ON CREATE SET r2.created = datetime().epochSeconds ON MATCH SET r2.updated = datetime().epochSeconds
      MERGE (branch)-[r3:has_student]->(user) ON CREATE SET r3.created = datetime().epochSeconds ON MATCH SET r3.updated = datetime().epochSeconds
      MERGE (user)-[r4: is_studying]->(sem) ON CREATE SET r4.created = datetime().epochSeconds ON MATCH SET r4.updated = datetime().epochSeconds
      RETURN r3 as r
      ",
    {dep: dep, user: user, br: {title: depData.branch, semester: userData.semester}, admin: admin}) YIELD value
    return user as n,value.r as r
    """

    batch =
      Enum.filter(
        changesets,
        fn %{
             user: %Changeset{valid?: b1},
             department: %Changeset{valid?: b2}
           } ->
          b1 && b2
        end
      )
      |> Enum.map(fn %{
                       user: %Changeset{changes: user},
                       department: %Changeset{changes: department}
                     } ->
        %{user: user, department: department}
      end)

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: data} = Sips.query!(conn, query, %{batch: batch, id: id})

      users =
        Enum.map(data, fn k ->
          {:ok, user} = structify_response(k, :user, "no such node found")
          user
        end)

      {:ok, users}
    rescue
      e ->
        IO.inspect(e)
        {:error, e}
    end
  end

  def get_user(:id, id) do
    query = "MATCH (n : User)<-[r]-() WHERE n.id='#{id}' RETURN n,r"

    conn = Sips.conn()
    %Bolt.Sips.Response{results: [data | _]} = Sips.query!(conn, query)
    structify_response(data, :user, "no such node found")
  rescue
    e -> {:error, reason: e.message}
  end

  def get_user(:email, email) do
    query = "MATCH (n : User)<-[r]-() WHERE n.email='#{email}' RETURN n,r"

    try do
      conn = Sips.conn()
      %Bolt.Sips.Response{results: [data | _]} = Sips.query!(conn, query)
      structify_response(data, :user, "no such node found")
    rescue
      e -> {:error, reason: e.message}
    end
  end

  def update_user_password(id, password) do
    query =
      "MATCH (n: User) WHERE n.id = '#{id}' SET n += { hashed_password: '#{password}' } RETURN true"

    conn = Sips.conn()

    try do
      _ = Sips.query!(conn, query)
      {:ok, true}
    rescue
      e -> {:error, e}
    end
  end

  def create_department(%{title: title, dep: dep, email: email} = data, id) do
    branches =
      case data do
        %{branches: branches} ->
          branches
          |> Enum.map(fn %Changeset{changes: branch} ->
            branch
          end)

        _ ->
          []
      end

    IO.inspect(branches)

    query =
      if Enum.count(branches) <= 0,
        do: """
        MATCH (admin:Admin) WHERE admin.id='#{id}'
        MERGE (admin)-[r:has_department]->(dep:Department{title:"#{title}", dep: "#{dep}", email: "#{email}"})
        ON CREATE SET r.created = datetime().epochSeconds
        ON MATCH SET r.updated = datetime().epochSeconds
        RETURN dep as n, r
        """,
        else: """
        MATCH (admin:Admin) WHERE admin.id='#{id}'
        MERGE (admin)-[r:has_department]->(dep:Department{title:"#{title}", dep: "#{dep}", email: "#{email}"})
        ON CREATE SET r.created = datetime().epochSeconds
        ON MATCH SET r.updated = datetime().epochSeconds
        with dep, r
        UNWIND $branches_data as row
        MERGE (dep)-[r2:has_branch]->(b:Branch{title: row.title, branch_id: row.branch_id})
        ON CREATE SET r2.created = datetime().epochSeconds
        ON MATCH SET r2.updated = datetime().epochSeconds
        WITH COLLECT (b) as branches, dep, r
        RETURN dep as n, r, branches
        """

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: [data | _]} =
        Sips.query!(conn, query, %{branches_data: branches})

      {:ok, department} = structify_response(data, :department, "failed to create")
      {:ok, department}
    rescue
      e ->
        IO.inspect(e)
    end
  end

  def get_departments(_page, id) do
    query = """
    MATCH (admin:Admin {id: '#{id}'})-[r:has_department]->(dep:Department)
    OPTIONAL MATCH (dep)-[:has_branch]->(b)
    WITH COLLECT(b) as branches, dep, r
    RETURN dep as n, r, branches
    """

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: res} = Sips.query!(conn, query)

      deps =
        Enum.map(res, fn data ->
          structify_response(data, :department, "unable to structify")
        end)

      {:ok, deps}
    rescue
      e ->
        IO.inspect(e)
        {:error, e}
    end
  end
end
