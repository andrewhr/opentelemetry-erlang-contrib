import Config

config :opentelemetry_oban,
  ecto_repos: [OpentelemetryOban.TestRepo]

config :opentelemetry_oban, OpentelemetryOban.TestRepo,
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  database: "opentelemetry_oban_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :opentelemetry,
  processors: [{:otel_simple_processor, %{}}]
