defmodule OpentelemetryOban.EngineTracer do
  @moduledoc false

  alias Ecto.Changeset
  alias Oban.Config
  alias Oban.Job

  require OpenTelemetry.Tracer

  def insert_job(engine, %Config{} = conf, %Changeset{} = changeset, opts) do
    attributes = attributes_before_insert(changeset)
    worker = Changeset.get_field(changeset, :worker, "unknown")

    OpenTelemetry.Tracer.with_span "#{worker} send", attributes: attributes, kind: :producer do
      changeset = add_tracing_information_to_meta(changeset)

      case engine.insert_job(conf, changeset, opts) do
        {:ok, job} ->
          OpenTelemetry.Tracer.set_attributes(attributes_after_insert(job))
          {:ok, job}

        other ->
          other
      end
    end
  end

  def insert_all_jobs(engine, %Config{} = conf, changesets, opts) when is_list(changesets) do
    # changesets in insert_all can include different workers and different
    # queues. This means we cannot provide much information here, but we can
    # still record the insert and propagate the context information.
    OpenTelemetry.Tracer.with_span :"Oban bulk insert", kind: :producer do
      changesets = Enum.map(changesets, &add_tracing_information_to_meta/1)
      engine.insert_all_jobs(conf, changesets, opts)
    end
  end

  defp add_tracing_information_to_meta(changeset) do
    meta = Changeset.get_field(changeset, :meta, %{})

    new_meta =
      []
      |> :otel_propagator_text_map.inject()
      |> Enum.into(meta)

    Changeset.change(changeset, %{meta: new_meta})
  end

  defp attributes_before_insert(changeset) do
    queue = Changeset.get_field(changeset, :queue, "unknown")
    worker = Changeset.get_field(changeset, :worker, "unknown")

    %{
      "messaging.system": :oban,
      "messaging.destination": queue,
      "messaging.destination_kind": :queue,
      "messaging.oban.worker": worker
    }
  end

  defp attributes_after_insert(%Job{} = job) do
    %{
      "messaging.oban.job_id": job.id,
      "messaging.oban.priority": job.priority,
      "messaging.oban.max_attempts": job.max_attempts
    }
  end
end
