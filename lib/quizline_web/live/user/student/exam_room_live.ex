defmodule QuizlineWeb.User.Student.ExamRoomLive do
  use QuizlineWeb, :live_view

  alias QuizlineWeb.Presence
  alias Quizline.PubSub
  alias Quizline.EventManager
  alias Quizline.UserManager.{Guardian, Student}
  import QuizlineWeb.Live.Utilities.BookLoader

  def mount(%{"room" => room_id}, %{"guardian_default_token" => token}, socket) do
    case Guardian.resource_from_token(token) do
      {:ok, %Student{} = user, %{"deviceId" => deviceId}} ->
        case EventManager.get_event(room_id) do
          nil ->
            {:ok, socket |> redirect(to: "/error")}

          exam ->
            Phoenix.PubSub.subscribe(PubSub, "exam_session_" <> room_id)

            Presence.track(self(), "exam_session_" <> room_id, user.id, %{
              deviceId: deviceId,
              pid: self(),
              session_start: DateTime.utc_now()
            })

            Registry.register(Quizline.SessionRegistry, user.id, self())

            {:ok,
             socket
             |> assign(:show_multiple_session_error, false)
             |> assign(:user, user)
             |> assign(:exam, exam)
             |> assign(:deviceId, deviceId)
             |> assign(:approval_status, :apply)
             |> assign(:room_id, room_id)
             |> assign(:stream_started, nil)
             |> assign(:is_mic_enabled, true)
             |> assign(:show_upload_form, false)
             |> assign(:is_video_enabled, true)
             |> allow_upload(:photo_id,
               accept: ~w(.pdf .jpg .png .jpeg),
               max_entries: 1,
               external: &presign_upload/2
             )}
        end

      _ ->
        {:ok, socket |> redirect(to: "/error")}
    end
  end

  def mount(_, _, socket) do
    {:ok, socket |> redirect(to: "/error")}
  end

  @bucket "quizline"
  defp spaces_host(), do: "//#{@bucket}.ams3.digitaloceanspaces.com"
  defp spaces_key(socket), do: "#{socket.assigns.room_id}.#{socket.assigns.user.id}"

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
        max_file_size: uploads.photo_id.max_file_size,
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

  def handle_event("video-stream-started", _, socket) do
    {:noreply, socket |> assign(:stream_started, true)}
  end

  def handle_event("frontend-error", error, socket) do
    IO.inspect(error)
    {:noreply, socket |> assign(:stream_started, false)}
  end

  def handle_event("hide-upload-form", _, socket) do
    {:noreply,
     socket
     |> assign(:show_upload_form, false)}
  end

  def handle_event("toggle-video", _, socket) do
    is_enabled = socket.assigns.is_video_enabled

    {:noreply,
     socket
     |> assign(:is_video_enabled, !is_enabled)}
  end

  def handle_event("id-file-changed", _, socket) do
    {:noreply, socket}
  end

  def handle_event("id-file-uploaded", _, socket) do
    {:noreply,
     socket
     |> assign(:show_upload_form, false)
     |> assign(:approval_status, :waiting)
     |> push_event("join-exam-channel", %{
       user: socket.assigns.user,
       room_id: socket.assigns.room_id
     })}
  end

  def handle_event("toggle-audio", _, socket) do
    is_enabled = socket.assigns.is_mic_enabled

    {:noreply,
     socket
     |> assign(:is_mic_enabled, !is_enabled)}
  end

  def handle_event("request-invigilator", _, socket) do
    {:noreply,
     socket
     |> assign(:show_upload_form, true)}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "presence_diff",
          payload: %{joins: joins, leaves: leaves}
        },
        socket
      ) do
    case {Map.keys(joins) |> Enum.find(nil, &(&1 == socket.assigns.user.id)),
          Map.keys(leaves) |> Enum.find(nil, &(&1 == socket.assigns.user.id))} do
      {nil, nil} ->
        {:noreply, socket}

      {jkey, lkey} ->
        if not is_nil(jkey) do
          %{metas: sessions} = Presence.get_by_key("exam_session_#{socket.assigns.room_id}", jkey)

          if Enum.count(sessions) > 1 do
            {:noreply, socket |> assign(:show_multiple_session_error, true)}
          else
            {:noreply, socket}
          end
        else
          %{metas: sessions} = Presence.get_by_key("exam_session_#{socket.assigns.room_id}", lkey)

          if Enum.count(sessions) <= 1 do
            {:noreply, socket |> assign(:show_multiple_session_error, false)}
          else
            {:noreply, socket}
          end
        end
    end
  end

  def ftime(time) do
    {:ok, ftime} =
      Time.from_iso8601!(time)
      |> Timex.format("{h12}:{0m} {am}")

    ftime
  rescue
    _ -> time
  end
end
