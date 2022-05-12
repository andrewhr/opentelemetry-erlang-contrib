defmodule OpentelemetryOban.Engines.BasicTest do
  use DataCase

  require OpenTelemetry.Tracer
  require OpenTelemetry.Span
  require Record

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/otel_span.hrl") do
    Record.defrecord(name, spec)
  end

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry_api/include/opentelemetry.hrl") do
    Record.defrecord(name, spec)
  end

  setup do
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    start_supervised!(
      {Oban, repo: OpentelemetryOban.TestRepo, engine: OpentelemetryOban.Engines.Basic}
    )

    OpentelemetryOban.setup()

    :ok
  end

  describe "insert/2" do
    test "records span on job insertion" do
      {:ok, %{id: job_id}} = Oban.insert(TestJob.new(%{}))
      assert %{success: 1} = Oban.drain_queue(queue: :events)

      assert_receive {:span,
                      span(
                        name: "TestJob send",
                        attributes: attributes,
                        parent_span_id: :undefined,
                        kind: :producer,
                        status: :undefined
                      )}

      assert %{
               "messaging.system": :oban,
               "messaging.destination": "events",
               "messaging.destination_kind": :queue,
               "messaging.oban.job_id": ^job_id,
               "messaging.oban.max_attempts": 1,
               "messaging.oban.priority": 0,
               "messaging.oban.worker": "TestJob"
             } = :otel_attributes.map(attributes)
    end

    test "propagate traces between send and process" do
      Oban.insert(TestJob.new(%{}))
      assert %{success: 1} = Oban.drain_queue(queue: :events)

      assert_receive {:span,
                      span(
                        name: "TestJob send",
                        attributes: _attributes,
                        trace_id: send_trace_id,
                        span_id: send_span_id,
                        kind: :producer,
                        status: :undefined
                      )}

      assert_receive {:span,
                      span(
                        name: "TestJob process",
                        attributes: _attributes,
                        kind: :consumer,
                        status: :undefined,
                        trace_id: process_trace_id,
                        links: links
                      )}

      assert [
               link(trace_id: ^send_trace_id, span_id: ^send_span_id)
             ] = :otel_links.list(links)

      # Process is ran asynchronously so we create a new trace, but still link
      # the traces together.
      assert send_trace_id != process_trace_id
    end
  end

  describe "insert_all/2" do
    test "propagate traces between send and process" do
      [_job_1, _job_2] =
        OpentelemetryOban.insert_all([
          TestJob.new(%{}),
          TestJob.new(%{})
        ])

      assert %{success: 2} = Oban.drain_queue(queue: :events)

      assert_receive {:span,
                      span(
                        name: :"Oban bulk insert",
                        attributes: _attributes,
                        trace_id: send_trace_id,
                        span_id: send_span_id,
                        kind: :producer,
                        status: :undefined
                      )}

      assert_receive {:span,
                      span(
                        name: "TestJob process",
                        attributes: _attributes,
                        kind: :consumer,
                        status: :undefined,
                        trace_id: job_1_process_trace_id,
                        links: job_1_links
                      )}

      assert [
               link(trace_id: ^send_trace_id, span_id: ^send_span_id)
             ] = :otel_links.list(job_1_links)

      assert_receive {:span,
                      span(
                        name: "TestJob process",
                        attributes: _attributes,
                        kind: :consumer,
                        status: :undefined,
                        trace_id: job_2_process_trace_id,
                        links: job_2_links
                      )}

      assert [
               link(trace_id: ^send_trace_id, span_id: ^send_span_id)
             ] = :otel_links.list(job_2_links)

      # Process is ran asynchronously so we create a new trace, but still link
      # the traces together.
      assert send_trace_id != job_1_process_trace_id
      assert send_trace_id != job_2_process_trace_id
      assert job_1_process_trace_id != job_2_process_trace_id
    end
  end
end
