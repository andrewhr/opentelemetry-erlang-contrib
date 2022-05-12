defmodule OpentelemetryOban.Pro.Queue.SmartEngine do
  alias Oban.Engine
  alias Oban.Pro.Queue.SmartEngine
  alias OpentelemetryOban.EngineTracer

  @behaviour Oban.Engine

  @impl Engine
  defdelegate init(conf, opts), to: SmartEngine

  @impl Engine
  defdelegate shutdown(conf, meta), to: SmartEngine

  @impl Engine
  defdelegate refresh(conf, meta), to: SmartEngine

  @impl Engine
  defdelegate put_meta(conf, meta, key, value), to: SmartEngine

  @impl Engine
  defdelegate check_meta(conf, meta, running), to: SmartEngine

  @impl Engine
  def insert_job(conf, changeset, opts) do
    EngineTracer.insert_job(SmartEngine, conf, changeset, opts)
  end

  @impl Engine
  defdelegate insert_job(conf, multi, name, changeset_or_fun, opts), to: SmartEngine

  @impl Engine
  def insert_all_jobs(conf, changesets, opts) do
    EngineTracer.insert_all_jobs(Basic, conf, changesets, opts)
  end

  @impl Engine
  defdelegate insert_all_jobs(conf, multi, name, changesets_or_wrapper_or_fun, opts),
    to: SmartEngine

  @impl Engine
  defdelegate fetch_jobs(conf, meta, running), to: SmartEngine

  @impl Engine
  defdelegate complete_job(conf, job), to: SmartEngine

  @impl Engine
  defdelegate discard_job(conf, job), to: SmartEngine

  @impl Engine
  defdelegate error_job(conf, job, seconds), to: SmartEngine

  @impl Engine
  defdelegate snooze_job(conf, job, seconds), to: SmartEngine

  @impl Engine
  defdelegate cancel_job(conf, job), to: SmartEngine

  @impl Engine
  defdelegate cancel_all_jobs(conf, queryable), to: SmartEngine

  @impl Engine
  defdelegate retry_job(conf, job), to: SmartEngine

  @impl Engine
  defdelegate retry_all_jobs(conf, queryable), to: SmartEngine
end
