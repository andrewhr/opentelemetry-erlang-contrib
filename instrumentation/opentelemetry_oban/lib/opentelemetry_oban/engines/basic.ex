defmodule OpentelemetryOban.Engines.Basic do
  alias Oban.Engine
  alias Oban.Engines.Basic
  alias OpentelemetryOban.EngineTracer

  @behaviour Oban.Engine

  @impl Engine
  defdelegate init(conf, opts), to: Basic

  @impl Engine
  defdelegate shutdown(conf, meta), to: Basic

  @impl Engine
  defdelegate refresh(conf, meta), to: Basic

  @impl Engine
  defdelegate put_meta(conf, meta, key, value), to: Basic

  @impl Engine
  defdelegate check_meta(conf, meta, running), to: Basic

  @impl Engine
  def insert_job(conf, changeset, opts) do
    EngineTracer.insert_job(Basic, conf, changeset, opts)
  end

  @impl Engine
  defdelegate insert_job(conf, multi, name, changeset_or_fun, opts), to: Basic

  @impl Engine
  def insert_all_jobs(conf, changesets, opts) do
    EngineTracer.insert_all_jobs(Basic, conf, changesets, opts)
  end

  @impl Engine
  defdelegate insert_all_jobs(conf, multi, name, changesets_or_wrapper_or_fun, opts), to: Basic

  @impl Engine
  defdelegate fetch_jobs(conf, meta, running), to: Basic

  @impl Engine
  defdelegate complete_job(conf, job), to: Basic

  @impl Engine
  defdelegate discard_job(conf, job), to: Basic

  @impl Engine
  defdelegate error_job(conf, job, seconds), to: Basic

  @impl Engine
  defdelegate snooze_job(conf, job, seconds), to: Basic

  @impl Engine
  defdelegate cancel_job(conf, job), to: Basic

  @impl Engine
  defdelegate cancel_all_jobs(conf, queryable), to: Basic

  @impl Engine
  defdelegate retry_job(conf, job), to: Basic

  @impl Engine
  defdelegate retry_all_jobs(conf, queryable), to: Basic
end
