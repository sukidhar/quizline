defmodule QuizlineWeb.InputHelper do
  use Phoenix.HTML
  import Phoenix.HTML.Form
  import QuizlineWeb.ErrorHelpers

  def floating_input(form, field, opts \\ []) do
    type = Phoenix.HTML.Form.input_type(form, field)
    should_force_error = Keyword.get(opts, :show_error) || false

    input_opts =
      [
        "border",
        "rounded-md",
        "focus:outline-none",
        "focus:border-primary-focus",
        "focus:shadow-sm",
        "peer",
        "h-16",
        "p-3",
        "w-full"
      ] ++ (Keyword.get(opts, :input) || [])

    label_opts =
      [
        "absolute",
        "top-0",
        "left-0",
        "px-3",
        "py-5",
        "h-full",
        "pointer-events-none",
        "transform ",
        "origin-left",
        "transistion-all duration-150",
        "ease-in-out",
        "peer-focus-within:text-primary-focus"
      ] ++ (Keyword.get(opts, :label) || [])

    wrapper_opts = [
      class: Enum.join(["floating-input"] ++ (Keyword.get(opts, :wrapper) || []), " ")
    ]

    error_tag = error_tag(form, field, should_force_error)
    IO.inspect(form)

    input_opts = [
      class: Enum.join(input_opts, " ") <> "#{if should_force_error, do: " force-error"}",
      placeholder: humanize(field),
      phx_debounce: "blur",
      id: "DOM-input-#{field}"
    ]

    label_opts = [
      class: Enum.join(label_opts, " ") <> "#{if should_force_error, do: " force-error"}",
      id: "DOM-label-#{field}"
    ]

    content_tag :div, wrapper_opts do
      [
        apply(Phoenix.HTML.Form, type, [form, field, input_opts]),
        label(form, field, humanize(field), label_opts),
        error_tag
      ]
    end
  end
end
