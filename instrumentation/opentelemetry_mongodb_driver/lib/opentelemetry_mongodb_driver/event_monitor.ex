defmodule OpentelemetryMongodbDriver.EventMonitor do
  @moduledoc false
  use GenServer

  alias Mongo.Events.CommandFailedEvent
  alias Mongo.Events.CommandSucceededEvent

  @doc false
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  def register_start_span(monitor \\ __MODULE__, connection_id, request_id, span) do
    GenServer.call(monitor, {:start_span, connection_id, request_id, span})
  end

  defstruct spans: %{}, monitors: %{}

  @impl GenServer
  def init(_opts) do
    {:ok, _} = Registry.register(:events_registry, :commands, [])
    {:ok, %__MODULE__{}}
  end

  @impl GenServer
  def handle_call(request, from, state)

  def handle_call({:start_span, connection_id, request_id, span}, _from, state) do
    new_monitors = maybe_monitor(state.monitors, connection_id)
    new_spans = put_span(state.spans, connection_id, request_id, span)
    {:reply, :ok, %{state | monitors: new_monitors, spans: new_spans}}
  end

  @impl GenServer
  def handle_info(message, state)

  def handle_info({:broadcast, :commands, %CommandSucceededEvent{} = event}, state) do
    case pop_span(state.spans, event.connection_id, event.request_id) do
      {s, new_spans} ->
        OpenTelemetry.Span.end_span(s)
        {:noreply, %{state | spans: new_spans} |> maybe_gc(event.connection_id)}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:broadcast, :commands, %CommandFailedEvent{failure: failure} = event}, state) do
    case pop_span(state.spans, event.connection_id, event.request_id) do
      {s, new_spans} ->
        OpenTelemetry.Span.set_status(s, OpenTelemetry.status(:error, format_error(failure)))
        OpenTelemetry.Span.end_span(s)
        {:noreply, %{state | spans: new_spans} |> maybe_gc(event.connection_id)}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:broadcast, :commands, _event}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, connection_id, _reason}, state) do
    new_monitors = Map.delete(state.monitors, connection_id)
    {:noreply, %{state | monitors: new_monitors} |> maybe_gc(connection_id)}
  end

  defp maybe_monitor(monitors, connection_id) do
    case Map.fetch(monitors, connection_id) do
      {:ok, _monitor} ->
        monitors

      :error ->
        Map.put(monitors, connection_id, Process.monitor(connection_id))
    end
  end

  defp maybe_gc(state, connection_id) do
    with :error <- Map.fetch(state.monitors, connection_id),
         {:ok, spans} when map_size(spans) == 0 <- Map.fetch(state.spans, connection_id) do
      %{state | spans: Map.delete(spans, connection_id)}
    else
      _ -> state
    end
  end

  defp put_span(spans, connection_id, request_id, span) do
    spans
    |> Map.put_new(connection_id, %{})
    |> Map.update!(connection_id, &Map.put(&1, request_id, span))
  end

  defp pop_span(spans, connection_id, request_id) do
    case get_in(spans, [connection_id, request_id]) do
      nil ->
        :error

      val ->
        {val, Map.update!(spans, connection_id, &Map.delete(&1, request_id))}
    end
  end

  defp format_error(exception) when is_exception(exception), do: Exception.message(exception)
  defp format_error(_), do: ""
end
