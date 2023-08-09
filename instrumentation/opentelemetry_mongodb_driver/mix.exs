defmodule OpentelemetryMongodbDriver.MixProject do
  use Mix.Project

  def project do
    [
      app: :opentelemetry_mongodb_driver,
      description: description(),
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
        plt_core_path: "priv/plts",
        plt_local_path: "priv/plts"
      ],
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      source_url:
        "https://github.com/open-telemetry/opentelemetry-erlang-contrib/tree/main/instrumentation/opentelemetry_mongodb_driver",
      docs: [
        source_url_pattern:
          "https://github.com/open-telemetry/opentelemetry-erlang-contrib/blob/main/instrumentation/opentelemetry_mongodb_driver/%{path}#L%{line}",
        main: "OpentelemetryMongodbDriver",
        extras: ["README.md"]
      ]
    ]
  end

  defp description do
    "Trace MongoDB queries with OpenTelemetry."
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" =>
          "https://github.com/open-telemetry/opentelemetry-erlang-contrib/tree/main/instrumentation/opentelemetry_mongodb_driver",
        "OpenTelemetry Erlang" => "https://github.com/open-telemetry/opentelemetry-erlang",
        "OpenTelemetry Erlang Contrib" =>
          "https://github.com/open-telemetry/opentelemetry-erlang-contrib",
        "OpenTelemetry.io" => "https://opentelemetry.io"
      }
    ]
  end

  def application do
    [
      mod: {OpentelemetryMongodbDriver.Application, []},
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30.0", only: [:dev], runtime: false},
      {:jason, "~> 1.0"},
      {:mongodb_driver, "~> 1.0", only: [:dev, :test]},
      {:nimble_options, "~> 1.0"},
      {:opentelemetry, "~> 1.0", only: [:dev, :test]},
      {:opentelemetry_api, "~> 1.0"},
      {:opentelemetry_exporter, "~> 1.0", only: [:dev, :test]},
      {:opentelemetry_process_propagator, "~> 0.2.0"},
      {:opentelemetry_semantic_conventions, "~> 0.2.0"},
      {:opentelemetry_telemetry, "~> 1.0"},
      {:telemetry, "~> 0.4 or ~> 1.0"}
    ]
  end
end
