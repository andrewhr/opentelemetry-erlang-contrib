defmodule OpentelemetryMongodbDriver.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {OpentelemetryMongodbDriver.EventMonitor, []}
    ]

    opts = [strategy: :one_for_one, name: OpentelemetryMongodbDriver.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
