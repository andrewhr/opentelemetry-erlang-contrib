defmodule OpentelemetryMongodbDriverTest do
  use ExUnit.Case, async: true

  doctest OpentelemetryMongodbDriver

  require OpenTelemetry.Tracer, as: Tracer
  require Record

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/otel_span.hrl") do
    Record.defrecord(name, spec)
  end

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry_api/include/opentelemetry.hrl") do
    Record.defrecord(name, spec)
  end

  setup_all do
    conn =
      start_supervised!(
        {Mongo,
         database: "opentelemetry_mongodb_driver_test",
         seeds: ["127.0.0.1:27017"],
         show_sensitive_data_on_connection_error: true}
      )

    :ok = Mongo.drop_database(conn, nil, w: 3)
    :ok = Mongo.create(conn, "entries")

    {:ok, [conn: conn]}
  end

  setup do
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    :ok
  end

  test "records span on commands", %{conn: conn} do
    OpentelemetryMongodbDriver.setup()
    on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

    {:ok, _} = Mongo.insert_one(conn, "entries", %{"value" => 42})
    %{"value" => 42} = Mongo.find_one(conn, "entries", %{"value" => 42})

    assert_receive {:span,
                    span(
                      name: "entries.insert",
                      kind: :client,
                      attributes: attributes
                    )}

    assert %{
             "db.operation": :insert,
             "db.mongodb.collection": "entries",
             "db.system": :mongodb
           } = :otel_attributes.map(attributes)

    refute is_map_key(:otel_attributes.map(attributes), :"db.statement")

    assert_receive {:span,
                    span(
                      name: "entries.find",
                      kind: :client,
                      attributes: attributes
                    )}

    assert %{
             "db.operation": :find,
             "db.mongodb.collection": "entries",
             "db.system": :mongodb
           } = :otel_attributes.map(attributes)

    refute is_map_key(:otel_attributes.map(attributes), :"db.statement")
  end

  test "correlates with parent span", %{conn: conn} do
    OpentelemetryMongodbDriver.setup()
    on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

    Tracer.with_span "parent span" do
      {:ok, _} = Mongo.insert_one(conn, "entries", %{"value" => 42})
    end

    assert_receive {:span, span(name: "parent span", span_id: parent_span_id)}
    assert_receive {:span, span(name: "entries.insert", parent_span_id: ^parent_span_id)}
  end

  test "sets error message on error", %{conn: conn} do
    OpentelemetryMongodbDriver.setup()
    on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

    {:error, _} = Mongo.find(conn, "entries", %{"$foo" => []})

    assert_receive {:span, span(name: "entries.find", status: status)}
    assert {:status, :error, message} = status
    assert message =~ "unknown top level operator: $foo"
  end

  describe "db.statement :plain" do
    test "record plain db.statement on find", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :plain)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      Mongo.find_one(conn, "entries", %{"value" => 42})

      assert_receive {:span,
                      span(
                        name: "entries.find",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)
      assert from_json(db_statement) == %{"filter" => %{"value" => 42}}
    end

    test "record obfuscated db.statement on complex find", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :plain)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      object_id = Mongo.object_id()
      object_id_str = object_id |> BSON.ObjectId.encode!()

      Mongo.find_one(conn, "entries", %{"$or" => [%{"_id" => object_id}]})

      assert_receive {:span,
                      span(
                        name: "entries.find",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)
      assert from_json(db_statement) == %{"filter" => %{"$or" => [%{"_id" => object_id_str}]}}
    end

    test "record plain db.statement on findAndModify", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :plain)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      Mongo.find_one_and_update(conn, "entries", %{"value" => 42}, %{"$set" => %{"value" => 72}})

      assert_receive {:span,
                      span(
                        name: "entries.findAndModify",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)

      assert from_json(db_statement) == %{
               "new" => false,
               "query" => %{"value" => 42},
               "update" => %{"$set" => %{"value" => 72}}
             }
    end

    test "record plain db.statement on update", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :plain)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      Mongo.update_one(conn, "entries", %{"value" => 42}, %{"$set" => %{"value" => 72}})

      assert_receive {:span,
                      span(
                        name: "entries.update",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)

      assert from_json(db_statement) == %{
               "updates" => [
                 %{
                   "multi" => false,
                   "q" => %{"value" => 42},
                   "u" => %{"$set" => %{"value" => 72}}
                 }
               ]
             }
    end

    test "record plain db.statement on delete", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :plain)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      Mongo.delete_one(conn, "entries", %{"value" => 42})

      assert_receive {:span,
                      span(
                        name: "entries.delete",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)

      assert from_json(db_statement) == %{
               "deletes" => [
                 %{
                   "limit" => 1,
                   "q" => %{"value" => 42}
                 }
               ]
             }
    end

    test "record plain db.statement on pipeline", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :plain)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      Mongo.count_documents(conn, "entries", %{"values" => 42})

      assert_receive {:span,
                      span(
                        name: "entries.aggregate",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)

      assert from_json(db_statement) == %{
               "pipeline" => [
                 %{"$match" => %{"values" => 42}},
                 %{"$group" => %{"_id" => nil, "n" => %{"$sum" => 1}}}
               ]
             }
    end
  end

  describe "db.statement :obfuscated" do
    test "record obfuscated db.statement on find", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :obfuscated)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      Mongo.find_one(conn, "entries", %{"value" => 42})

      assert_receive {:span,
                      span(
                        name: "entries.find",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)
      assert from_json(db_statement) == %{"filter" => %{"value" => "?"}}
    end

    test "record obfuscated db.statement on complex find", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :obfuscated)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      object_id = Mongo.object_id()

      Mongo.find_one(conn, "entries", %{"$or" => [%{"_id" => object_id}]})

      assert_receive {:span,
                      span(
                        name: "entries.find",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)
      assert from_json(db_statement) == %{"filter" => %{"$or" => [%{"_id" => "?"}]}}
    end

    test "record obfuscated db.statement on findAndModify", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :obfuscated)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      Mongo.find_one_and_update(conn, "entries", %{"value" => 42}, %{"$set" => %{"value" => 72}})

      assert_receive {:span,
                      span(
                        name: "entries.findAndModify",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)

      assert from_json(db_statement) == %{
               "new" => false,
               "query" => %{"value" => "?"},
               "update" => %{"$set" => %{"value" => "?"}}
             }
    end

    test "record obfuscated db.statement on update", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :obfuscated)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      Mongo.update_one(conn, "entries", %{"value" => 42}, %{"$set" => %{"value" => 72}})

      assert_receive {:span,
                      span(
                        name: "entries.update",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)

      assert from_json(db_statement) == %{
               "updates" => [
                 %{
                   "multi" => false,
                   "q" => %{"value" => "?"},
                   "u" => %{"$set" => %{"value" => "?"}}
                 }
               ]
             }
    end

    test "record obfuscated db.statement on delete", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :obfuscated)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      Mongo.delete_one(conn, "entries", %{"value" => 42})

      assert_receive {:span,
                      span(
                        name: "entries.delete",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)

      assert from_json(db_statement) == %{
               "deletes" => [
                 %{
                   "limit" => 1,
                   "q" => %{"value" => "?"}
                 }
               ]
             }
    end

    test "record obfuscated db.statement on pipeline", %{conn: conn} do
      OpentelemetryMongodbDriver.setup(db_statement: :obfuscated)
      on_exit(fn -> OpentelemetryMongodbDriver.detach() end)

      Mongo.count_documents(conn, "entries", %{"values" => 42})

      assert_receive {:span,
                      span(
                        name: "entries.aggregate",
                        kind: :client,
                        attributes: attributes
                      )}

      assert %{"db.statement": db_statement} = :otel_attributes.map(attributes)

      assert from_json(db_statement) == %{
               "pipeline" => [
                 %{"$match" => %{"values" => "?"}},
                 %{"$group" => %{"_id" => "?", "n" => %{"$sum" => "?"}}}
               ]
             }
    end
  end

  defp from_json(json), do: Jason.decode!(json)
end
