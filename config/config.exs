# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config
# GUARDIAN config
config :quizline, Quizline.AdminManager.Guardian,
  issuer: "quizline",
  secret_key: "gMbFA1ERHmI7NL74p4nbe9c0/Y3zNz3EFHsPzk9wIQg4ZV+bAXIVsEC/WgMsAUht"

config :quizline, Quizline.UserManager.Guardian,
  issuer: "quizline",
  secret_key: "AqbchZHVvzTKwlrpFeQr0lm1OcTUyPZZCx1db3vzu4mF5nSvLO8Ozw/vS2/8Nbnt"

# email validator
config :email_checker,
  default_dns: :system,
  also_dns: [],
  validations: [EmailChecker.Check.Format, EmailChecker.Check.MX],
  smtp_retries: 2,
  timeout_milliseconds: :infinity

config :quizline, Necto,
  modules: %{
    admin: Quizline.AdminManager.Admin,
    user: %{
      invigilator: Quizline.UserManager.Invigilator,
      student: Quizline.UserManager.Student
    },
    student: Quizline.UserManager.Student,
    department: Quizline.DepartmentManager.Department,
    branch: Quizline.DepartmentManager.Department.Branch,
    semester: Quizline.SemesterManager.Semester,
    subject: Quizline.SubjectManager.Subject,
    exam: Quizline.EventManager.Exam,
    room: Quizline.EventManager.Exam.Room
  }

# configures neo4j database connection
config :bolt_sips, Bolt,
  url: "bolt://localhost:7687",
  basic_auth: [username: "neo4j", password: "letmein"],
  pool_size: 10

config :quizline, Xandra,
  name: QXandra,
  pool_size: 10,
  nodes: ["localhost:9042"],
  authentication: {Xandra.Authenticator.Password, [username: "cassandra", password: "cassandra"]}

# Configures the endpoint
config :quizline, QuizlineWeb.Endpoint,
  url: [host: "lvh.me"],
  render_errors: [view: QuizlineWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Quizline.PubSub,
  live_view: [signing_salt: "mBd/Y27G"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :quizline, Quizline.Mailer, adapter: Swoosh.Adapters.Local

config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :room, :peer]

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :info],
    # Silence irrelevant warnings caused by resending handshake events
    [module: Membrane.SRTP.Encryptor, function: "handle_event/4", level_lower_than: :error]
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
