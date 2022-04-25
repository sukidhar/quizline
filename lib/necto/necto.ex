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
        response
        |> Enum.map(fn data ->
          case data do
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

              Kernel.struct!(struct, props)

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

              Kernel.struct!(struct, props)
          end
        end)

      %{label: :semester, modules: %{semester: struct}} ->
        response
        |> Enum.map(fn %{
                         "semester" => %Bolt.Sips.Types.Node{properties: properties},
                         "r" => %Bolt.Sips.Types.Relationship{properties: rel_props}
                       } ->
          props =
            convert_to_klist(properties)
            |> Keyword.put(
              :created,
              "#{rel_props["created"] || DateTime.to_unix(DateTime.utc_now())}"
            )

          Kernel.struct!(struct, props)
        end)

      %{label: :branch, modules: %{branch: struct}} ->
        response
        |> Enum.map(fn %{"new_branch" => %Bolt.Sips.Types.Node{properties: properties}} ->
          props = convert_to_klist(properties)
          [branch, id] = Keyword.get(props, :id, "unknown@id") |> String.split("@")

          props =
            props
            |> Keyword.put(:id, id)
            |> Keyword.put(:branch_id, branch)

          Kernel.struct!(struct, props)
        end)

      %{label: :subject, modules: %{subject: struct}} ->
        response
        |> Enum.map(fn %{
                         "subject" => %Bolt.Sips.Types.Node{properties: properties},
                         "r" => %Bolt.Sips.Types.Relationship{properties: rel_props}
                       } ->
          props =
            convert_to_klist(properties)
            |> Keyword.put(
              :created,
              "#{rel_props["created"] || DateTime.to_unix(DateTime.utc_now())}"
            )
            |> Keyword.put(
              :updated,
              "#{rel_props["updated"] || nil}"
            )

          Kernel.struct!(struct, props)
        end)

      _ ->
        throw("Struct Module not mentioned in config.exs")
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

    query =
      if Enum.count(branches) <= 0,
        do: """
        MATCH (admin:Admin) WHERE admin.id='#{id}'
        CREATE (admin)-[r:has_department{created: datetime().epochSeconds}]->(dep:Department{title:"#{title}", dep: "#{dep}", email: "#{email}"})
        RETURN dep as n, r
        """,
        else: """
        MATCH (admin:Admin) WHERE admin.id='#{id}'
        CREATE (admin)-[r:has_department{created: datetime().epochSeconds}]->(dep:Department{title:"#{title}", dep: "#{dep}", email: "#{email}"})
        with dep, r
        UNWIND $branches_data as row
        CREATE (dep)-[r2:has_branch{created: datetime().epochSeconds}]->(b:Branch{title: row.title, branch_id: row.branch_id})
        WITH COLLECT (b) as branches, dep, r
        RETURN dep as n, r, branches
        """

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: results} = Sips.query!(conn, query, %{branches_data: branches})

      [department | _] = structify_response(results, :department, "failed to create")

      {:ok, department}
    rescue
      e ->
        {:error, e}
    end
  end

  def create_departments(data, id) do
    IO.inspect(data)

    query = """
    MATCH (admin:Admin {id: $id})
    with admin
    UNWIND $data as row
    MERGE (admin)-[r:has_department]->(dep:Department {title:row.title, dep: row.dep, email: row.email})
    ON CREATE SET r.created = datetime().epochSeconds
    ON MATCH SET r.updated = datetime().epochSeconds
    RETURN dep as n, r
    """

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: data} = Sips.query!(conn, query, %{data: data, id: id})
      deps = structify_response(data, :department, "failed to create")
      {:ok, deps}
    rescue
      e ->
        {:error, e}
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

      deps = structify_response(res, :department, "unable to structify")
      {:ok, deps}
    rescue
      e ->
        IO.inspect(e)
        {:error, e}
    end
  end

  def create_branch(%{id: id} = params) do
    [branch | _] = id |> String.split("@")
    params = params |> Map.put(:prefix, branch <> "@")

    query = """
    MATCH (dep:Department{email:$email})
    OPTIONAL MATCH (dep)-[:has_branch]-(branch:Branch)
    WHERE branch.title STARTS WITH $prefix
    CALL {
        with dep, branch
        with dep, branch
        where branch is null
        CREATE (dep)-[:has_branch]->(b:Branch{title:$title, id:$id})
        return True as result, b as new_branch
        UNION
        with dep, branch
        with dep, branch
        where branch is not null
        return False as result, branch as new_branch
    }
    RETURN new_branch, result
    """

    conn = Sips.conn()

    %Bolt.Sips.Response{results: res} = Sips.query!(conn, query, params)

    IO.inspect(res)

    case res do
      [%{"result" => true} | _] ->
        {:ok, structify_response(res, :branch, "failed to create a branch")}

      _ ->
        raise("failed to branch because it already exists")
    end

    # rescue
    #   e -> {:error, "failed to create branch due to", e}
  end

  def create_branches(data, email) do
    IO.inspect(data)

    query = """
    MATCH (dep:Department {email: $email})
    UNWIND $data as row
    MERGE (dep)-[r:has_branch]->(branch:Branch)
    """
  end

  def delete_branch(id) do
    query = """
    MATCH (b:Branch{id: $id}) DETACH DELETE b
    """

    conn = Sips.conn()

    try do
      _ = Sips.query!(conn, query, %{id: id})
      {:ok, true}
    rescue
      e -> {:error, "Failed to delete branch due to ", e}
    end
  end

  def create_semester(params, id) do
    query = """
    MATCH (admin:Admin) WHERE admin.id=$id
    CREATE (admin)-[r:has_semester{created: datetime().epochSeconds}]->(semester:Semester $params)
    RETURN semester, r
    """

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: response} = Sips.query!(conn, query, %{id: id, params: params})
      semsters = structify_response(response, :semester, "unable to structify to semester")
      {:ok, semsters}
    rescue
      e -> {:error, "Failed to create semester due to ", e}
    end
  end

  def get_semesters(id) do
    query = """
    MATCH (admin:Admin) WHERE admin.id = $id
    MATCH (admin)-[r:has_semester]->(semester:Semester)
    return semester, r
    """

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: response} = Sips.query!(conn, query, %{id: id})

      semsters = structify_response(response, :semester, "unable to structify to semester")
      {:ok, semsters}
    rescue
      e -> {:error, "Failed to create semester due to ", e}
    end
  end

  def create_subject(params, dep_email) do
    query = """
    MATCH (dep:Department{email: $email})
    CREATE (dep)-[r:has_subject{created: datetime().epochSeconds}]->(subject:Subject $params)
    RETURN subject, r
    """

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: response} =
        Sips.query!(conn, query, %{email: dep_email, params: params})

      semsters = structify_response(response, :subject, "unable to structify to semester")
      {:ok, semsters}
    rescue
      e -> {:error, "Failed to create subject due to ", e}
    end
  end

  def create_subjects(data) do
    query = """
    UNWIND $batch as row
    MATCH (dep:Department)
    WHERE dep.email = row.email
    MERGE (dep)-[r:has_subject]->(subject:Subject {title: row.sub.title, subject_code: row.sub.subject_code})
    ON CREATE SET r.created = datetime().epochSeconds
    ON MATCH SET r.updated = datetime().epochSeconds
    """

    conn = Sips.conn()

    try do
      _ = Sips.query!(conn, query, %{batch: data})
      {:ok, "subjects are created successfully"}
    rescue
      e -> {:error, "Failed to fetch subjects due to ", e}
    end
  end

  def get_subjects(dep_email) do
    query = """
    MATCH (dep:Department {email: $email})-[r:has_subject]->(subject:Subject)
    RETURN subject,r
    """

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: response} = Sips.query!(conn, query, %{email: dep_email})
      {:ok, structify_response(response, :subject, "unable to structify to subject")}
    rescue
      e -> {:error, "Failed to fetch subjects due to ", e}
    end
  end
end
