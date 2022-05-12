defmodule OpentelemetryOban.Pro.Plugins.DynamicQueues do
  @moduledoc false

  @behaviour Oban.Plugin

  @impl Oban.Plugin
  defdelegate start_link(opts), to: Oban.Pro.Plugins.DynamicQueues

  @engine_mapping %{
    OpenTelemetryOban.Pro.Queue.SmartEngine => Oban.Pro.Queue.SmartEngine
  }

  @impl Oban.Plugin
  def validate(opts) do
    opts
    |> Keyword.update(:engine, nil, &Map.get(@engine_mapping, &1, &1))
    |> Oban.Pro.Plugins.DynamicQueues.validate()
  end

  # Not explicit part of Plugin contract, but required by Oban.Config validations
  defdelegate init(opts), to: Oban.Pro.Plugins.DynamicQueues
end
