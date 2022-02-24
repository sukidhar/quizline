defmodule QuizlineWeb.AdminAuthLive do
  use QuizlineWeb, :live_view
  import QuizlineWeb.InputHelper

  alias Quizline.AdminManager
  alias Quizline.AdminManager.Admin

  def mount(_params, _session, socket) do
    changeset = AdminManager.registration_change_admin(%Admin{})

    {:ok,
     socket
     |> assign(current_step: 1)
     |> assign(force_errors: false)
     |> assign(changeset: changeset)}
  end

  def handle_event("validate", %{"admin" => admin_params}, socket) do
    changeset =
      %Admin{}
      |> AdminManager.registration_change_admin(admin_params)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("next-step", _params, socket) do
    current_step = socket.assigns.current_step
    changeset = socket.assigns.changeset |> Map.put(:action, :insert)

    errors = []

    is_invalid =
      case current_step do
        1 ->
          ^errors =
            intersection(Keyword.keys(changeset.errors), [:first_name, :last_name, :email])

          Enum.any?(Keyword.keys(changeset.errors), fn k ->
            k in [:first_name, :last_name, :email]
          end)

        _ ->
          false
      end

    current_step = if is_invalid, do: current_step, else: current_step + 1

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:current_step, if(is_invalid, do: current_step, else: current_step + 1))
     |> assign(:force_errors, is_invalid)}
  end

  defp intersection(map1, map2) do
    map1 = MapSet.new(map1)
    map2 = Mapset.new(map2)
    intersection(map1, map2)
  end
end
