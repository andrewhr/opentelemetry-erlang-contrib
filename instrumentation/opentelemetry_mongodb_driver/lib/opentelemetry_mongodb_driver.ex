defmodule OpentelemetryMongodbDriver do
  @moduledoc """
  OpentelemetryMongodbDriver uses [telemetry](https://hexdocs.pm/telemetry/) handlers to
  and Mongo a event listener create `OpenTelemetry` spans.

  ## Usage

  In your application start:

      def start(_type, _args) do
        OpentelemetryMongodbDriver.setup()

        # ...
      end

  """

  alias OpenTelemetry.SemanticConventions
  alias OpentelemetryMongodbDriver.Command

  require OpenTelemetry.SemanticConventions.Trace
  require OpenTelemetry.Tracer

  @execution_start [:mongodb_driver, :start]

  @options_schema NimbleOptions.new!(
                    db_statement: [
                      type: {:in, [:disabled, :plain, :obfuscated, {:fun, 1}]},
                      default: :disabled,
                      doc: ~s"""
                      Whether or not incllude db statements. Could be any of:
                      * `:disabled` - omit db statements
                      * `:plain` - include the entire statement without sanitization 
                      * `:obfuscated` - include the entire statement with default obsfuscation

                      Optionally a function can be provided that takes a `keyword()` representing
                      the command and returns a sanitized version of it as string.
                      """
                    ]
                  )

  @typedoc "Setup options"
  @type opts() :: unquote(NimbleOptions.option_typespec(@options_schema))

  @doc """
  Initializes and configures the telemetry handlers.

  ## Options

  #{NimbleOptions.docs(@options_schema)}

  """
  @spec setup(opts()) :: :ok
  def setup(opts \\ []) do
    config = Map.new(NimbleOptions.validate!(opts, @options_schema))

    :telemetry.attach(
      {__MODULE__, :execution},
      @execution_start,
      &__MODULE__.handle_event/4,
      config
    )

    :ok
  end

  # private use for test
  @doc false
  def detach do
    :telemetry.detach({__MODULE__, :execution})
  end

  @doc false
  def handle_event(event, measurements, metadata, config)

  def handle_event(@execution_start, _measurements, metadata, config) do
    collection = extract_collection(metadata.command)

    span_name =
      if collection do
        "#{collection}.#{metadata.command_name}"
      else
        metadata.command_name
      end

    # metadata.command |> IO.inspect(label: "\nCMD")
    attributes =
      %{
        SemanticConventions.Trace.db_system() => :mongodb,
        SemanticConventions.Trace.db_name() => metadata.database_name,
        SemanticConventions.Trace.db_operation() => metadata.command_name
        # FIXME not available
        # SemanticConventions.Trace.db_connection_string() => "...",
        # TODO need connection information to complete the required attributes
        # net.peer.name or net.peer.ip and net.peer.port
        # SemanticConventions.Trace.net_peer_name() => "...",
        # SemanticConventions.Trace.net_peer_port() => "...",
      }
      |> maybe_put(SemanticConventions.Trace.db_mongodb_collection(), collection)
      |> maybe_put(SemanticConventions.Trace.db_statement(), sanitize(metadata.command, config))

    s =
      OpenTelemetry.Tracer.start_span(span_name, %{
        kind: :client,
        attributes: attributes
      })

    :ok =
      OpentelemetryMongodbDriver.EventMonitor.register_start_span(
        metadata.connection_id,
        metadata.request_id,
        s
      )
  end

  defp extract_collection([{_, collection} | _]) when is_binary(collection), do: collection
  defp extract_collection(_command), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp sanitize(_command, %{db_statement: :disabled}), do: nil

  defp sanitize(command, %{db_statement: db_statement}) when is_function(db_statement),
    do: db_statement.(command)

  defp sanitize(command, %{db_statement: db_statement}),
    do: Command.sanitize(command, db_statement == :obfuscated)
end
