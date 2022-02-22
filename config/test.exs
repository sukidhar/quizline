import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :quizline, QuizlineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "dpDt1KPP7bwpApJyO26M6QNHa8/ZDNw2CYKoJkeXE7TeX4ls72ZHcFHAYDcYs/S8",
  server: false

# In test we don't send emails.
config :quizline, Quizline.Mailer,
  adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
