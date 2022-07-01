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
      <p class="w-full text-center h-fit -mt-14 animate-bounce"><%= text %></p>
    </div>
    """
  end
end
