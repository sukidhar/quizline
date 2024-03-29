defmodule Quizline.MixProject do
  use Mix.Project

  def project do
    [
      app: :quizline,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      xref: [exclude: [Poison.Parser, Poison]]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Quizline.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.6"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.17.5"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:esbuild, "~> 0.3", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.10"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:bolt_sips, "~> 2.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:guardian, "~> 2.0"},
      {:argon2_elixir, "~> 3.0"},
      {:email_checker, "~> 0.2.4"},
      {:csv, "~> 2.4"},
      {:timex, "~> 3.0"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:eqrcode, "~> 0.1.10"},
      {:aws, "~> 0.11.0"},
      {:hackney, "~> 1.18"},
      {:pigeon, "~> 1.6.1"},
      {:kadabra, "~> 0.6.0"},

      # membrane
      {:membrane_rtc_engine, "~> 0.3.0"},
      # otel
      {:opentelemetry, "~> 0.6.0", override: true},
      {:opentelemetry_api, "~> 0.6.0", override: true},
      {:opentelemetry_exporter, "~> 0.6.0"},
      {:opentelemetry_zipkin, "~> 0.4.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "cmd --cd assets npm install"],
      "assets.deploy": [
        "cmd --cd assets npm run deploy",
        "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end
end
