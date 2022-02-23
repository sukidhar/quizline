defmodule QuizlineWeb.InputHelper do
  use Phoenix.HTML
  import Phoenix.HTML.Form

  def floating_input(form, field, opts \\ []) do
    type = Phoenix.HTML.Form.input_type(form, field)

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

    label_opts =
      if form.errors[field],
        do: label_opts ++ ["text-error-content"],
        else: label_opts ++ ["text-primary-content"]

    input_opts =
      if form.errors[field],
        do: input_opts ++ ["border-error"],
        else: input_opts ++ ["border-gray-200"]

    input_opts = [
      class: Enum.join(input_opts, " "),
      placeholder: humanize(field),
      phx_debounce: "blur"
    ]

    label_opts = [class: Enum.join(label_opts, " ")]

    content_tag :div, wrapper_opts do
      [
        apply(Phoenix.HTML.Form, type, [form, field, input_opts]),
        label(form, field, humanize(field), label_opts)
      ]
    end
  end
end
