defmodule QuizlineWeb.Plug.Subdomain do
  import Plug.Conn
  @doc false
  def init(default), do: default

  @doc false
  def call(conn, router) do
    case get_subdomain(conn.host) do
      "admin" ->
        conn
        |> put_private(:subdomain, "admin")
        |> router.call(router.init({}))
        |> halt

      "incharge" ->
        conn
        |> put_private(:subdomain, "incharge")
        |> router.call(router.init({}))
        |> halt

      _ ->
        conn
    end
  end

  defp get_subdomain(host) do
    root_host = QuizlineWeb.Endpoint.config(:url)[:host]
    String.replace(host, ~r/.?#{root_host}/, "")
  end
end
