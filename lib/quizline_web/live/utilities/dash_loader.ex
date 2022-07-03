defmodule QuizlineWeb.Live.Utilities.DashLoader do
  use Phoenix.Component

  def dash_loader(%{text: text} = assigns) do
    ~H"""
    <div class="w-full h-full flex flex-col justify-center items-center">
      <div class="dash-container">
        <div class="dash uno"></div>
        <div class="dash dos"></div>
        <div class="dash tres"></div>
        <div class="dash cuatro"></div>
      </div>
      <%= if text != "" do %>
        <p class={pos(assigns, "w-full text-center h-fit animate-bounce")}><%= text %></p>
      <% end %>
    </div>
    """
  end

  defp pos(%{pos: pos}, classlist) do
    classlist <> "-mt-[#{pos * 0.25}rem]"
  end

  defp pos(_, classlist) do
    classlist <> "-mt-14"
  end
end
