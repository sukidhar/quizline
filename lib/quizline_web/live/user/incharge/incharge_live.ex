defmodule QuizlineWeb.User.Incharge.InchargeLive do
  use QuizlineWeb, :live_view

  alias Quizline.Guardian
  alias Quizline.EventManager
  import QuizlineWeb.InputHelpers
  alias Quizline.EventManager.Exam.QuestionPaper

  def mount(%{"token" => token}, _, socket) do
    case Guardian.decode_and_verify(token) do
      {:ok, %{"sub" => %{"email" => email, "event" => event}}} ->
        with {[exam], bool} <-
               {EventManager.fetch_question_papers(event), EventManager.qps_distributed?(event)} do
          IO.inspect(bool)

          {:ok,
           socket
           |> assign(:email, email)
           |> assign(:exam, exam)
           |> assign(:fid, UUID.uuid4())
           |> assign(:upload_error, false)
           |> assign(:view_document, nil)
           |> assign(:distributed?, bool)
           |> assign(
             :qp_changeset,
             EventManager.qp_changeset(%QuestionPaper{})
           )
           |> allow_upload(:question_paper,
             accept: ~w(.pdf .docx .txt .rtf),
             max_entries: 1,
             external: &presign_upload/2
           )}
        else
          {{:error, _}, {:error, _}} ->
            {:ok, socket |> redirect(to: "/error")}

          {{:error, _}, _} ->
            {:ok, socket |> redirect(to: "/error")}

          {_, {:error, _}} ->
            {:ok, socket |> redirect(to: "/error")}
        end

      _ ->
        {:ok, socket |> redirect(to: "/error")}
    end
  end

  def handle_event("qp-change", %{"question_paper" => params}, socket) do
    {:noreply,
     socket
     |> assign(
       :qp_changeset,
       %QuestionPaper{}
       |> EventManager.qp_changeset(params)
       |> Map.put(:action, :insert)
     )
     |> assign(:upload_error, false)}
  end

  def handle_event("qp-submit", %{"question_paper" => params}, socket) do
    if socket.assigns.uploads.question_paper.entries |> Enum.count() > 0 do
      changeset =
        %QuestionPaper{}
        |> EventManager.qp_changeset(
          params
          |> Map.put("id", socket.assigns.fid)
          |> Map.put("uploader", socket.assigns.email)
        )
        |> Map.put(:action, :validate)

      _ =
        consume_uploaded_entries(socket, :question_paper, fn _, _ ->
          {:ok, nil}
        end)

      case EventManager.set_qp(socket.assigns.exam.id, changeset.changes) do
        {:error, e} ->
          IO.inspect(e)
          {:noreply, socket}

        qp ->
          {:noreply,
           socket
           |> assign(
             :exam,
             socket.assigns.exam
             |> Map.update!(:question_papers, fn v ->
               v ++ [qp]
             end)
           )
           |> assign(:fid, UUID.uuid4())
           |> assign(:qp_changeset, EventManager.qp_changeset(%QuestionPaper{}))}
      end
    else
      {:noreply, socket |> assign(:upload_error, true)}
    end
  end

  def handle_event("remove-qp", %{"qp_id" => id}, socket) do
    case EventManager.delete_qp(id) do
      {:error, e} ->
        IO.inspect(e)
        {:noreply, socket}

      :ok ->
        delete_object(id, socket)

        {:noreply,
         socket
         |> assign(
           :exam,
           socket.assigns.exam
           |> Map.update!(:question_papers, fn v ->
             Enum.reject(v, &(&1.id == id))
           end)
         )}
    end
  end

  def handle_event("view-document", %{"id" => id}, socket) do
    {:noreply, socket |> assign(:view_document, generate_query(id, socket))}
  end

  def handle_event("hide-document", _, socket) do
    {:noreply, socket |> assign(:view_document, nil)}
  end

  def handle_event("distribute-qps", _, socket) do
    if socket.assigns.exam.question_papers |> Enum.count() <= 0 do
      {:noreply, socket}
    else
      if socket.assigns.distributed? do
        EventManager.redistribute_qps(socket.assigns.exam.id)
      else
        EventManager.distribute_qps(socket.assigns.exam.id)
      end
      |> IO.inspect()
      |> case do
        :ok -> {:noreply, socket |> assign(:distributed?, true)}
        {:error, e} -> {:noreply, socket}
      end
    end
  end

  def is_changeset_valid(%Ecto.Changeset{valid?: valid}) do
    valid
  end

  @bucket "quizline"
  defp spaces_host(), do: "//#{@bucket}.ams3.digitaloceanspaces.com"

  defp spaces_key(socket),
    do: "qp-#{socket.assigns.exam.id}/#{socket.assigns.fid}"

  def presign_upload(entry, socket) do
    uploads = socket.assigns.uploads
    key = spaces_key(socket)

    config = %{
      scheme: "https://",
      host: "ams3.digitaloceanspaces.com",
      region: "us-east-1",
      access_key_id: System.fetch_env!("SPACES_KEY"),
      secret_access_key: System.fetch_env!("SPACES_SECRET")
    }

    {:ok, fields} =
      SimpleS3Upload.sign_form_upload(config, @bucket,
        key: key,
        content_type: entry.client_type,
        max_file_size: uploads.question_paper.max_file_size,
        expires_in: :timer.hours(12)
      )

    meta = %{
      uploader: "S3",
      key: key,
      url: spaces_host(),
      fields: fields
    }

    {:ok, meta, socket}
  end

  def date(unix) do
    {int, _} =
      unix
      |> Integer.parse()

    int
    |> DateTime.from_unix!()
    |> Timex.from_now()
  end

  def delete_object(key, socket) do
    client =
      AWS.Client.create(
        System.fetch_env!("SPACES_KEY"),
        System.fetch_env!("SPACES_SECRET"),
        "us-east-1"
      )

    client =
      AWS.Client.put_endpoint(client, "ams3.digitaloceanspaces.com") |> Map.put(:service, "s3")

    key = "qp-#{socket.assigns.exam.id}/#{key}"

    AWS.S3.delete_object(client, @bucket, key, %{})
  end

  def generate_query(key, socket) do
    client =
      AWS.Client.create(
        System.fetch_env!("SPACES_KEY"),
        System.fetch_env!("SPACES_SECRET"),
        "us-east-1"
      )

    client =
      AWS.Client.put_endpoint(client, "ams3.digitaloceanspaces.com") |> Map.put(:service, "s3")

    url =
      "https://#{client.endpoint}/#{AWS.Util.encode_uri(@bucket)}/qp-#{AWS.Util.encode_uri(socket.assigns.exam.id)}/#{AWS.Util.encode_uri(key)}"

    %{
      headers:
        AWS.Signature.sign_v4(
          client,
          NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          :get,
          url,
          [{"Content-Type", "text/xml"}],
          ""
        )
        |> Map.new(),
      url: url
    }
  end
end
