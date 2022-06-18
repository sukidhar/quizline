defmodule Necto do
  alias Ecto.Changeset
  alias Bolt.Sips

  def create(%Changeset{valid?: true, changes: fields} = changeset, :admin) do
    query = "CREATE (n:Admin) SET #{format_data(fields)} RETURN n"

    conn = Sips.conn()

    try do
      with {:fetch, {:ok, data}} <-
             {:fetch,
              Sips.query!(conn, query)
              |> structify_response(:admin, "no such node found")} do
        {:ok, data}
      else
        {:fetch, {:error, reason}} -> {:error, changeset, reason: reason}
      end
    rescue
      e -> {:error, e.message}
    end
  end

  def create(
        %Changeset{
          valid?: true,
          changes: %{
            semester: %Changeset{changes: semester},
            branch: %Changeset{changes: branch},
            email: email,
            first_name: first_name,
            last_name: last_name,
            rid: rid,
            id: id
          }
        } = _changeset,
        :student
      ) do
    query = """
    MATCH (sem:Semester {id: $sid }), (branch: Branch {id: $bid})
    CREATE (user:Student:User {id: $id, email: $email, first_name: $first_name, last_name: $last_name, rid: $rid })
    MERGE (sem)-[:has_student]->(user)-[:pursuing]->(branch)
    """

    conn = Sips.conn()

    Sips.query!(
      conn,
      query,
      %{
        email: email,
        first_name: first_name,
        last_name: last_name,
        rid: rid,
        bid: branch.branch_id <> "@" <> branch.id,
        sid: semester.id,
        id: id
      }
    )
    |> case do
      %Sips.Response{stats: %{"nodes-created" => 1}} ->
        :ok

      _ ->
        raise "already exists or unknown error"
    end
  rescue
    e -> {:error, e}
  end

  def create(
        %Changeset{
          valid?: true,
          changes: %{
            department: %Changeset{changes: department},
            email: email,
            first_name: first_name,
            last_name: last_name,
            id: id
          }
        } = _changeset,
        :invigilator
      ) do
    query = """
    MATCH (dep:Department {email: $d_email })
    CREATE (user:Invigilator:User {id: $id, email: $email, first_name: $first_name, last_name: $last_name})
    MERGE (dep)-[:has_invigilator]->(user)
    """

    conn = Sips.conn()

    Sips.query!(
      conn,
      query,
      %{
        email: email,
        first_name: first_name,
        last_name: last_name,
        d_email: department.email,
        id: id
      }
    )
    |> case do
      %Sips.Response{stats: %{"nodes-created" => 1}} ->
        :ok

      _ ->
        raise "already exists or unknown error"
    end
  rescue
    e -> {:error, e}
  end

  def create(%Changeset{valid?: false} = changeset, _b) do
    {:error, changeset}
  end

  def create_bulk_user_accounts({students, invigilators}, id) do
    main_conn = Sips.conn()

    try do
      Sips.transaction(main_conn, fn conn ->
        query = """
        UNWIND $students as student
        MATCH (admin:Admin{id: $id})-[:has_semester]->(sem:Semester {sid: student.semester })
        WITH sem, student
        MATCH (branch:Branch) WHERE branch.id STARTS WITH student.branch + "@"
        CREATE (user:Student:User {id: student.id, email: student.email, first_name: student.first_name, last_name: student.last_name, rid: student.rid })
        MERGE (sem)-[:has_student]->(user)-[:pursuing]->(branch)
        RETURN user
        """

        %Sips.Response{results: students} =
          Sips.query!(conn, query, %{students: students, id: id})

        students = structify_response(students, :user, "unable to structify the user data")

        query = """
        UNWIND $invigilators as invigilator
        MATCH (dep:Department {email: invigilator.department })
        CREATE (user:Invigilator:User {id: invigilator.id, email: invigilator.email, first_name: invigilator.first_name, last_name: invigilator.last_name})
        MERGE (dep)-[:has_invigilator]->(user)
        RETURN user
        """

        %Sips.Response{results: invigilators} =
          Sips.query!(conn, query, %{invigilators: invigilators})

        invigilators = structify_response(invigilators, :user, "unable to structify the user")

        {students, invigilators}
      end)
      |> IO.inspect()
    rescue
      e -> {:error, e}
    end
  end

  defp format_data(fields) do
    fields
    |> Enum.map(fn {k, v} -> "n.#{k} = '#{v}'" end)
    |> Enum.join(", ")
  end

  def structify_response(response, label, error) do
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

      %{
        label: :user,
        modules: %{user: %{student: student_struct, invigilator: invigilator_struct}}
      } ->
        response
        |> Enum.map(fn k ->
          case k do
            %{"user" => node, "r" => r} ->
              props =
                convert_to_klist(node.properties)
                |> Keyword.put(
                  :created_at,
                  "#{r.properties["created_at"] || DateTime.to_unix(DateTime.utc_now())}"
                )

              case String.downcase(hd(node.labels) || "student") do
                "student" -> Kernel.struct!(student_struct, props)
                "invigilator" -> Kernel.struct!(invigilator_struct, props)
              end

            %{"user" => node} ->
              props =
                convert_to_klist(node.properties)
                |> Keyword.put(:account_type, String.downcase(hd(node.labels) || "student"))

              case String.downcase(hd(node.labels) || "student") do
                "student" -> Kernel.struct!(student_struct, props)
                "invigilator" -> Kernel.struct!(invigilator_struct, props)
              end
          end
        end)

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

            %{"dep" => node} ->
              props = convert_to_klist(node.properties)
              Kernel.struct!(struct, props)
          end
        end)

      %{label: :semester, modules: %{semester: struct}} ->
        response
        |> Enum.map(fn k ->
          case k do
            %{
              "semester" => %Bolt.Sips.Types.Node{properties: properties},
              "r" => %Bolt.Sips.Types.Relationship{properties: rel_props}
            } ->
              props =
                convert_to_klist(properties)
                |> Keyword.put(
                  :created,
                  "#{rel_props["created"] || DateTime.to_unix(DateTime.utc_now())}"
                )

              props =
                props
                |> Keyword.put(:common?, Keyword.get(props, :common, false))
                |> Keyword.delete(:common)

              Kernel.struct!(struct, props)

            %{
              "semester" => %Bolt.Sips.Types.Node{properties: properties}
            } ->
              props = convert_to_klist(properties)

              props =
                props
                |> Keyword.put(:common?, Keyword.get(props, :common, false))
                |> Keyword.delete(:common)

              Kernel.struct!(struct, props)
          end
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
        case is_list(response) do
          true ->
            response
            |> Enum.map(fn k ->
              case k do
                %{
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

                %{
                  "subject" => %Bolt.Sips.Types.Node{properties: properties}
                } ->
                  props = convert_to_klist(properties)
                  Kernel.struct!(struct, props)
              end
            end)

          false ->
            case response do
              %{
                "subject" => %Bolt.Sips.Types.Node{properties: properties},
                "r" => %Bolt.Sips.Types.Relationship{properties: rel_props},
                "assocs" => assocs
              } ->
                assocs =
                  assocs
                  |> Enum.map(fn k ->
                    case k do
                      %{"branch" => nil, "sem" => nil} ->
                        nil

                      %{"branch" => _, "sem" => nil} ->
                        nil

                      %{"branch" => nil, "sem" => sem} ->
                        [semester] =
                          Necto.structify_response(
                            [%{"semester" => sem}],
                            :semester,
                            "failed to structify response"
                          )

                        Kernel.struct!(Module.concat([struct, Associate]),
                          branch: nil,
                          semester: semester
                        )

                      %{"branch" => branch, "sem" => sem} ->
                        [branch] =
                          Necto.structify_response(
                            [%{"new_branch" => branch}],
                            :branch,
                            "failed to structify response"
                          )

                        [semester] =
                          Necto.structify_response(
                            [%{"semester" => sem}],
                            :semester,
                            "failed to structify response"
                          )

                        Kernel.struct!(Module.concat([struct, Associate]),
                          branch: branch,
                          semester: semester
                        )
                    end
                  end)
                  |> Enum.reject(&is_nil/1)

                props =
                  convert_to_klist(properties)
                  |> Keyword.put(:associates, assocs)
                  |> Keyword.put(
                    :created,
                    "#{rel_props["created"] || DateTime.to_unix(DateTime.utc_now())}"
                  )
                  |> Keyword.put(
                    :updated,
                    "#{rel_props["updated"] || nil}"
                  )

                Kernel.struct!(struct, props)
            end
        end

      %{label: :exam, modules: %{exam: struct}} ->
        response
        |> Enum.map(fn k ->
          case k do
            %{"subject" => subject, "events" => events} ->
              [subject] = structify_response([subject], :subject, "unable to find subject")

              events
              |> Enum.map(fn %{
                               "event" => %Sips.Types.Node{
                                 properties: props,
                                 labels: ["Event", label]
                               },
                               "r" => %Sips.Types.Relationship{properties: rel_props}
                             } ->
                props =
                  convert_to_klist(props)
                  |> Keyword.put(
                    :exam_group,
                    label |> String.split("_") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
                  )
                  |> Keyword.put(
                    :created,
                    "#{rel_props["created"] || DateTime.to_unix(DateTime.utc_now())}"
                  )
                  |> Keyword.put(
                    :updated,
                    "#{rel_props["updated"] || nil}"
                  )

                props =
                  props
                  |> Keyword.put(
                    :date,
                    case Keyword.get(props, :date, nil) do
                      nil ->
                        nil

                      date ->
                        {date, ""} = Integer.parse(date)
                        date |> DateTime.from_unix!() |> DateTime.to_date()
                    end
                  )

                Kernel.struct!(struct, props)
                |> Map.put(:subject, subject)
              end)

            %{"rooms" => rooms} ->
              rooms
              |> Enum.map(fn %Sips.Types.Node{properties: props} ->
                props = convert_to_klist(props)
                Kernel.struct!(Module.concat([struct, Room]), props)
              end)

            %{"room" => %Bolt.Sips.Types.Node{properties: props}, "students" => students} ->
              students =
                students
                |> structify_response(:student, "unable to structify students")

              props =
                convert_to_klist(props)
                |> Keyword.put(:students, students)

              Kernel.struct!(Module.concat([struct, Room]), props)

            %{
              "event" => %Bolt.Sips.Types.Node{labels: ["Event", label], properties: props},
              "r" => %Sips.Types.Relationship{properties: rel_props},
              "room" => %Sips.Types.Node{properties: room_props},
              "subject" => subject
            } ->
              [subject] =
                structify_response([%{"subject" => subject}], :subject, "unable to find subject")

              props =
                convert_to_klist(props)
                |> Keyword.put(
                  :exam_group,
                  label |> String.split("_") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
                )
                |> Keyword.put(
                  :created,
                  "#{rel_props["created"] || DateTime.to_unix(DateTime.utc_now())}"
                )
                |> Keyword.put(
                  :updated,
                  "#{rel_props["updated"] || nil}"
                )

              props =
                props
                |> Keyword.put(
                  :date,
                  case Keyword.get(props, :date, nil) do
                    nil ->
                      nil

                    date ->
                      {date, ""} = Integer.parse(date)
                      date |> DateTime.from_unix!() |> DateTime.to_date()
                  end
                )

              Kernel.struct!(struct, props)
              |> Map.put(:subject, subject)
              |> Map.put(:rooms, [
                Kernel.struct!(
                  Module.concat([struct, Room]),
                  room_props |> convert_to_klist()
                )
              ])
          end
        end)
        |> List.flatten()

      %{label: :student, modules: %{student: struct}} ->
        response
        |> Enum.map(fn student_data ->
          case student_data do
            %{
              "student" => %Sips.Types.Node{properties: props},
              "semester" => semester,
              "branch" => branch
            } ->
              [semester] =
                structify_response(
                  [%{"semester" => semester}],
                  :semester,
                  "unable to structify semester"
                )

              [branch] =
                structify_response(
                  [%{"new_branch" => branch}],
                  :branch,
                  "unable to structify branch"
                )

              props =
                convert_to_klist(props)
                |> Keyword.put(:semester, semester)
                |> Keyword.put(:branch, branch)

              Kernel.struct!(struct, props)

            %{
              "student" => %Sips.Types.Node{properties: props},
              "assigned" => value
            } ->
              props = convert_to_klist(props)
              %{student: Kernel.struct!(struct, props), assigned: value}

            %{
              "student" => %Sips.Types.Node{properties: props}
            } ->
              props = convert_to_klist(props)
              Kernel.struct!(struct, props)
          end
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

  def get_user(:id, id) do
    query = "MATCH (user : User)<-[r]-() WHERE user.id='#{id}' RETURN user,r"

    conn = Sips.conn()
    %Bolt.Sips.Response{results: data} = Sips.query!(conn, query)

    structify_response(data, :user, "no such node found")
    |> case do
      [] -> raise "No such user exists"
      [user | _] -> {:ok, user}
    end
  rescue
    e -> {:error, reason: e.message}
  end

  def get_user(:email, email) do
    query = "MATCH (user : User)<-[r]-() WHERE user.email='#{email}' RETURN user,r"

    try do
      conn = Sips.conn()
      %Bolt.Sips.Response{results: data} = Sips.query!(conn, query)

      structify_response(data, :user, "no such node found")
      |> case do
        [] -> raise "No such user exists"
        [user | _] -> {:ok, user}
      end
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

    case res do
      [%{"result" => true} | _] ->
        {:ok, structify_response(res, :branch, "failed to create a branch")}

      _ ->
        raise("failed to branch because it already exists")
    end
  rescue
    e -> {:error, e}
  end

  def create_branches(data, email) do
    query = """
    UNWIND $data as row
        MATCH (dep:Department{email: $email})
        OPTIONAL MATCH (dep)-[:has_branch]-(branch:Branch)
        WHERE branch.title STARTS WITH row.branch.prefix
        CALL {
            with dep, branch, row
            with dep, branch, row
            where branch is null
            CREATE (dep)-[:has_branch]->(b:Branch{title: row.branch.title, id: row.branch.id})
            return True as result, b as new_branch
            UNION
            with dep, branch, row
            with dep, branch, row
            where branch is not null
            MERGE (dep)-[:has_branch]->(b:Branch {title: row.branch.title})
            return False as result, branch as new_branch
        }
        WITH new_branch, dep, row
        UNWIND (CASE row.links WHEN [] THEN [null] else row.links END) as link
        CALL{
          WITH new_branch, link
          WITH new_branch, link
          WHERE link is null
          RETURN false as res

          UNION

          WITH new_branch, link
          WITH new_branch, link
          WHERE link is not null
          MATCH (sem:Semester) WHERE sem.sid = link.semester
          WITH new_branch, link, sem
          MATCH (sub:Subject) WHERE sub.subject_code = link.subject
          FOREACH (ignoreMe in CASE WHEN sem.common THEN [1] ELSE [] END |  MERGE (sem)<-[:assigns]-(sub))
          FOREACH (ignoreMe2 in CASE WHEN sem.common THEN [] ELSE [1] END |   MERGE (sem)<-[:assigns]-(sub) MERGE (sub)<-[:provides]-(new_branch))
          RETURN true as res
        }
        RETURN new_branch, collect(link) as links
    """

    conn = Sips.conn()

    %Bolt.Sips.Response{results: res} = Sips.query!(conn, query, %{data: data, email: email})
    {:ok, structify_response(res, :branch, "failed to create a branch")}
  rescue
    e ->
      {:error, e}
  end

  def get_branches(email) do
    query = """
    MATCH (:Department{email: $email})-[has_branch]->(branch:Branch)
    RETURN branch as new_branch
    """

    conn = Sips.conn()

    %Bolt.Sips.Response{results: res} = Sips.query!(conn, query, %{email: email})
    {:ok, structify_response(res, :branch, "failed to create a branch")}
  rescue
    e ->
      {:error, e}
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
    params = params |> Map.put(:common, params.common?) |> Map.delete(:common?)

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

  def get_all_subjects_with_departments(id) do
    query = """
    MATCH (admin:Admin{id: $id})-[:has_department]-(dep:Department)-[r:has_subject]->(subject:Subject)
    OPTIONAL MATCH (sem:Semester)<-[:assigns]-(subject)
    OPTIONAL MATCH (subject)<-[:provides]-(branch:Branch)
    RETURN dep, subject, collect({sem: sem, branch: branch}) as assocs, r
    """

    conn = Sips.conn()

    try do
      %Bolt.Sips.Response{results: response} = Sips.query!(conn, query, %{id: id})

      Enum.map(response, fn %{"assocs" => assocs, "dep" => dep, "r" => r, "subject" => subject} ->
        [dep] =
          structify_response([%{"dep" => dep}], :department, "unable to structify department")

        subject =
          structify_response(
            %{"subject" => subject, "r" => r, "assocs" => assocs},
            :subject,
            "unable to structify department"
          )

        {subject, dep}
      end)
    rescue
      e -> {:error, "Failed to fetch subjects due to ", e}
    end
  end

  def create_exam_event(
        %{
          exam_group: exam_group,
          attendees: attendees,
          date: date,
          start_time: start_time,
          end_time: end_time,
          subject: %{subject_code: subject_code}
        },
        id
      ) do
    {:ok, date, _} = ((date |> Date.to_iso8601()) <> " 00:00:00+00:00") |> DateTime.from_iso8601()

    date =
      date
      |> DateTime.to_unix()

    start_time = Time.to_iso8601(start_time)
    end_time = Time.to_iso8601(end_time)

    rels =
      attendees
      |> Enum.map(fn k ->
        case k do
          %{branch: branch, semester: sem} ->
            %{
              branch: branch.branch_id <> "@" <> branch.id,
              semester: sem.sid
            }

          %{semester: sem} ->
            %{
              semester: sem.sid
            }
        end
      end)

    query = """
      UNWIND $rels as rel
      MATCH (sem:Semester{sid: rel.semester})-[:participates]->(exam:Event)
      WHERE exam.date = $date
      OPTIONAL MATCH (exam)<-[:participates]-(branch:Branch{id: rel.branch})
      RETURN collect({sem: rel.semester, branch: rel.branch, exam: exam}) as result
    """

    conn = Sips.conn()

    %Sips.Response{results: results} = Sips.query!(conn, query, %{rels: rels, date: "#{date}"})

    case results do
      [] ->
        nil

      [%{"result" => res} | _] ->
        res
        |> Enum.map(fn k ->
          case k do
            %{
              "branch" => branch,
              "exam" => %Sips.Types.Node{properties: exam},
              "sem" => sem
            } ->
              rels
              |> Enum.find(nil, fn x ->
                x.semester == sem and if x.branch == nil, do: true, else: x.branch == branch
              end)
              |> case do
                nil ->
                  nil

                _ ->
                  s1 = Time.from_iso8601!(exam["start_time"])
                  s2 = Time.from_iso8601!(start_time)
                  e1 = Time.from_iso8601!(exam["end_time"])
                  e2 = Time.from_iso8601!(end_time)

                  if Time.compare(s2, e1) not in [:gt, :eq] or
                       Time.compare(e2, s1) in [:lt, :eq] do
                    raise("One or more of the attendee grooups have conflict with exam timings")
                  end
              end
          end
        end)
    end

    query = """
    UNWIND $rels as rel
    MATCH (n:Student)<-[:has_student]-(sem:Semester{sid:rel.semester})
    CALL apoc.when(rel.branch is null,
    'RETURN n.email as student',
    'MATCH (branch:Branch{id: rel.branch})<-[:pursuing]-(n) RETURN n.email as student',
    {n: n, rel: rel}) YIELD value
    RETURN collect(value.student) as emails
    """

    conn = Sips.conn()

    %Sips.Response{results: [res | _]} = Sips.query!(conn, query, %{rels: rels})
    exam_group = exam_group |> String.split() |> Enum.join("_") |> String.upcase()

    groups =
      res["emails"]
      |> Enum.shuffle()
      |> Enum.chunk_every(12)

    query = """
    MATCH (admin:Admin{id: $id})-[:has_department]-()-[:has_invigilator]->(inv:Invigilator)
    with inv
    OPTIONAL MATCH (exam:Event) WHERE exam.date <> $date
    WITH (CASE not exists((inv)-[:monitors]->(:Room)<-[:has_room]-(exam))
    WHEN true THEN inv.email
    ELSE null
    END) as email
    RETURN apoc.coll.shuffle(collect(email))[0..$limit] as emails
    """

    %Sips.Response{results: [res | _]} =
      Sips.query!(conn, query, %{id: id, date: date, limit: groups |> Enum.count()})

    IO.inspect(res)
    invigilators = res["emails"]

    if Enum.count(invigilators) < groups |> Enum.count() do
      raise "insufficent invigilator count"
    end

    groups =
      Enum.zip(groups, invigilators)
      |> Enum.map(fn {k, inv} ->
        %{students: k, invigilator: inv}
      end)

    query = """
    MATCH (admin:Admin{id: "#{id}"})
    WITH admin
    MATCH (sub:Subject{subject_code: "#{subject_code}"})
    CREATE (admin)-[:has_event{created:datetime().epochSeconds}]->(exam:Event:#{exam_group}{id: apoc.create.uuid(), date: "#{date}", start_time: "#{start_time}", end_time: "#{end_time}"})-[:for{created:datetime().epochSeconds}]->(sub)
    with exam
    UNWIND $groups as group
    MATCH (inv:Invigilator {email: group.invigilator})
    CREATE (inv)-[:monitors]->(room:Room{id: apoc.create.uuid()})
    MERGE (exam)-[r:has_room]->(room)
    ON CREATE SET r.created = datetime().epochSeconds
    ON MATCH SET r.updated = datetime().epochSeconds
    with group, room, exam
    UNWIND group.students as email
    MATCH (student:Student{email: email})
    CREATE (room)<-[:is_assigned]-(student)
    with exam
    UNWIND $rels as rel
    CALL apoc.do.when(rel.branch is null,
    'MATCH (sem:Semester{sid: rel.semester})
    MERGE (sem)-[:participates]->(exam)
    RETURN exam',
    'MATCH (branch:Branch{id: rel.branch})
    with branch, rel, exam
    MATCH (sem:Semester{sid: rel.semester})
    MERGE (sem)-[:participates]->(exam)<-[:participates]-(branch)
    RETURN exam',
    {rel: rel, exam: exam})
    YIELD value
    RETURN distinct(value.exam) as exam
    """

    _ = Sips.query!(conn, query, %{groups: groups, rels: rels})
    :ok
  rescue
    e -> {:error, e}
  end

  def create_exam_event(_data, _id) do
    {:error, "data not in the required format"}
  end

  def delete_exam_event(id) do
    query = """
    MATCH (event:Event{id: $id})
    OPTIONAL MATCH (event)-[:has_room]->(room:Room)
    DETACH DELETE event
    DETACH DELETE room
    """

    conn = Sips.conn()

    res = Sips.query!(conn, query, %{id: id})

    case res do
      %Sips.Response{stats: %{"nodes-deleted" => count}} ->
        count >= 1

      _ ->
        false
    end
  rescue
    e -> {:error, e}
  end

  def create_multiple_exams(dataset, id) do
    main_conn = Sips.conn()

    Sips.transaction(main_conn, fn conn ->
      dataset
      |> Enum.map(fn data ->
        case data do
          %{
            exam_group: exam_group,
            attendees: attendees,
            date: date,
            start_time: start_time,
            end_time: end_time,
            subject: subject_code
          } ->
            query = """
              UNWIND $rels as rel
              MATCH (sem:Semester{sid: rel.semester})-[:participates]->(exam:Event)
              WHERE exam.date = $date
              OPTIONAL MATCH (exam)<-[:participates]-(branch:Branch)
              WHERE branch.id STARTS WITH rel.branch + "@"
              RETURN collect({sem: rel.semester, branch: branch.id, exam: exam}) as result
            """

            %Sips.Response{results: results} =
              Sips.query!(conn, query, %{rels: attendees, date: "#{date}"})

            case results do
              [] ->
                nil

              [%{"result" => res} | _] ->
                res
                |> Enum.map(fn k ->
                  case k do
                    %{
                      "branch" => branch,
                      "exam" => %Sips.Types.Node{properties: exam},
                      "sem" => sem
                    } ->
                      attendees
                      |> Enum.find(nil, fn x ->
                        [branch | _] = branch |> String.split("@")
                        x.branch == branch and x.semester == sem
                      end)
                      |> case do
                        nil ->
                          nil

                        _ ->
                          s1 = Time.from_iso8601!(exam["start_time"])
                          s2 = Time.from_iso8601!(start_time)
                          e1 = Time.from_iso8601!(exam["end_time"])
                          e2 = Time.from_iso8601!(end_time)

                          if Time.compare(s2, e1) not in [:gt, :eq] or
                               Time.compare(e2, s1) in [:lt, :eq] do
                            Sips.rollback(conn, :schedule_conflict)
                          end
                      end
                  end
                end)
            end

            query = """
            UNWIND $rels as rel
            MATCH (n:Student)<-[:has_student]-(sem:Semester{sid:rel.semester})
            CALL apoc.when(rel.branch is null,
            'RETURN n.email as student',
            'MATCH (branch:Branch)<-[:pursuing]-(n) WHERE branch.id STARTS WITH rel.branch + "@" RETURN n.email as student',
            {n: n, rel: rel}) YIELD value
            RETURN collect(value.student) as emails
            """

            %Sips.Response{results: [res | _]} = Sips.query!(conn, query, %{rels: attendees})
            exam_group = exam_group |> String.split() |> Enum.join("_") |> String.upcase()

            groups =
              res["emails"]
              |> Enum.shuffle()
              |> Enum.chunk_every(12)

            query = """
            MATCH (admin:Admin{id: $id})-[:has_department]-()-[:has_invigilator]->(inv:Invigilator)
            with inv
            OPTIONAL MATCH (exam:Event) WHERE exam.date <> $date
            WITH (CASE not exists((inv)-[:monitors]->(:Room)<-[:has_room]-(exam))
            WHEN true THEN inv.email
            ELSE null
            END) as email
            RETURN apoc.coll.shuffle(collect(email))[0..$limit] as emails
            """

            %Sips.Response{results: [%{"emails" => invigilators} | _]} =
              Sips.query!(conn, query, %{id: id, date: date, limit: groups |> Enum.count()})

            if Enum.count(invigilators) < groups |> Enum.count() do
              Sips.rollback(conn, :insufficient_invigilators)
            end

            groups =
              Enum.zip(groups, invigilators)
              |> Enum.map(fn {k, inv} ->
                %{students: k, invigilator: inv}
              end)

            query = """
            MATCH (admin:Admin{id: "#{id}"})
            WITH admin
            MATCH (sub:Subject{subject_code: "#{subject_code}"})
            CREATE (admin)-[:has_event{created:datetime().epochSeconds}]->(exam:Event:#{exam_group}{id: apoc.create.uuid(), date: "#{date}", start_time: "#{start_time}", end_time: "#{end_time}"})-[:for{created:datetime().epochSeconds}]->(sub)
            with exam
            UNWIND $groups as group
            MATCH (inv:Invigilator {email: group.invigilator})
            CREATE (inv)-[:monitors]->(room:Room{id: apoc.create.uuid()})
            MERGE (exam)-[r:has_room]-(room)
            ON CREATE SET r.created = datetime().epochSeconds
            ON MATCH SET r.updated = datetime().epochSeconds
            with group, room, exam
            UNWIND group.students as email
            MATCH (student:Student{email: email})
            CREATE (room)<-[:is_assigned]-(student)
            with exam
            UNWIND $rels as rel
            CALL apoc.do.when(rel.branch is null,
            'MATCH (sem:Semester{sid: rel.semester})
            MERGE (sem)-[:participates]->(exam)
            RETURN exam',
            'MATCH (branch:Branch)
            WHERE branch.id STARTS WITH rel.branch + "@"
            with branch, rel,exam
            MATCH (sem:Semester{sid: rel.semester})
            MERGE (sem)-[:participates]->(exam)<-[:participates]-(branch)
            RETURN exam',
            {rel: rel, exam: exam})
            YIELD value
            RETURN distinct(value.exam)
            """

            _ = Sips.query!(conn, query, %{groups: groups, rels: attendees})
            :ok

          _ ->
            Sips.rollback(conn, :invalid_format)
        end
      end)
    end)
    |> case do
      {:ok, _res} ->
        :ok

      e ->
        IO.inspect(e)
        e
    end
  end

  def fetch_exam_events(id) do
    query = """
    MATCH (admin:Admin {id: $id})-[:has_department]->()-[r1:has_subject]->(subject:Subject)<-[r2:for]-(event:Event)
    RETURN {subject: subject, r: r1} as subject, collect({event: event, r:r2}) as events
    """

    conn = Sips.conn()

    %Sips.Response{results: results} = Sips.query!(conn, query, %{id: id})
    results |> structify_response(:exam, "unable to structify exams")
  rescue
    e -> {:error, e}
  end

  def fetch_exam_event_details(id) do
    query = """
    MATCH (event:Event{id: $id})
    OPTIONAL MATCH (event)-[:has_room]-(room:Room)
    RETURN collect(room) as rooms
    """

    conn = Sips.conn()

    %Sips.Response{results: results} = Sips.query!(conn, query, %{id: id})
    structify_response(results, :exam, "unknown error occured")
  rescue
    e ->
      {:error, e}
  end

  def fetch_room_details(id) do
    query = """
    MATCH (room:Room{id: $id})<-[:is_assigned]-(student:Student)
    OPTIONAL MATCH (semester:Semester)-[:has_student]->(student:Student)-[:pursuing]-(branch:Branch)
    RETURN room, collect({student: student, branch: branch, semester: semester}) as students
    """

    conn = Sips.conn()
    %Sips.Response{results: results} = Sips.query!(conn, query, %{id: id})
    structify_response(results, :exam, "unable to fetch room details")
  rescue
    e ->
      {:error, e}
  end

  def remove_student_from_room(sid, room_id) do
    query = """
    MATCH (room:Room{id: $room_id})<-[r:is_assigned]-(student:Student{id: $sid})
    DELETE r
    """

    conn = Sips.conn()

    res = Sips.query!(conn, query, %{sid: sid, room_id: room_id})

    case res do
      %Sips.Response{stats: %{"relationships-deleted" => 1}} ->
        true

      _ ->
        false
    end
  rescue
    e -> {:error, e}
  end

  def add_student_to_room(sid, room_id) do
    query = """
    MATCH (room:Room{id: $room_id})-[:is_assigned]-(s:Student)
    WITH count(s) as scount, room
    MATCH (student:Student{id: $sid})
    FOREACH (ignoreMe in CASE WHEN scount < 12 THEN [1] ELSE [] END |  MERGE (room)<-[:is_assigned]-(student))
    RETURN student
    """

    conn = Sips.conn()

    res = Sips.query!(conn, query, %{sid: sid, room_id: room_id})

    case res do
      %Sips.Response{stats: %{"relationships-created" => 1}, results: res} ->
        [head | _] = structify_response(res, :student, "unable to structify")
        head

      _ ->
        false
    end
  rescue
    e -> {:error, e}
  end

  def get_students_fuzzy(keyword, event_id) do
    case String.split(String.trim(keyword)) do
      [] ->
        []

      [first_name | extras] ->
        conditions =
          case extras do
            [] ->
              """
              WHERE student.first_name =~ "(?i)#{first_name}.*" or student.last_name =~ "(?i)#{first_name}.*" or student.rid =~ "(?i)#{first_name}.*"
              """

            extras ->
              extras = Enum.join(extras, " ")

              """
              WHERE student.first_name =~ "(?i)#{first_name}.*"
              or student.first_name =~ "(?i)#{extras}.*"
              or student.last_name =~ "(?i)#{extras}.*"
              or student.last_name =~ "(?i)#{first_name}.*"
              """
          end

        query = """
        MATCH (event:Event{id: $event_id})-[:for]-(subject:Subject)
        MATCH (sem:Semester)-[:assigns]-(subject)-[:provides]-(branch:Branch)
        with event, sem, branch
        MATCH (sem)-[:has_student]-(student:Student)-[:pursuing]-(branch)
        #{conditions}
        RETURN distinct(student), exists((student)-[:is_assigned]-(:Room)-[:has_room]-(event)) as assigned
        ORDER BY assigned
        LIMIT 20
        """

        conn = Sips.conn()

        %Sips.Response{results: results} = Sips.query!(conn, query, %{event_id: event_id})
        structify_response(results, :student, "unable to structify")
    end
  end

  def fetch_departments(id) do
    query = """
    MATCH (admin:Admin {id: $id})-[:has_department]->(dep:Department)
    RETURN dep
    """

    conn = Sips.conn()
    %Sips.Response{results: results} = Sips.query!(conn, query, %{id: id})
    structify_response(results, :department, "unable to structify")
  rescue
    e -> {:error, e}
  end

  def fetch_all_branches(id) do
    query = """
    MATCH (admin:Admin {id: $id})-[:has_department]-()-[:has_branch]->(branch:Branch)
    RETURN branch as new_branch
    """

    conn = Sips.conn()
    %Sips.Response{results: results} = Sips.query!(conn, query, %{id: id})
    structify_response(results, :branch, "unable to structify")
  rescue
    e -> {:error, e}
  end

  def get_events_for_user(id) do
    query = """
    MATCH (user:User{id: $id})
    OPTIONAL MATCH (user)-[:is_assigned|:monitors]->(room:Room)<-[:has_room]-(event:Event)-[r:for]-(subject:Subject)
    RETURN room, event, r, subject
    """

    conn = Sips.conn()

    %Sips.Response{results: results} = Sips.query!(conn, query, %{id: id})

    structify_response(
      results |> Enum.reject(&is_nil(&1["event"])),
      :exam,
      "unable to structify"
    )
  rescue
    e -> {:error, e}
  end
end
