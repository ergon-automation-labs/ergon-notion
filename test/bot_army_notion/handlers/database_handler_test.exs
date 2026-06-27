defmodule BotArmyNotion.Handlers.DatabaseHandlerTest do
  use ExUnit.Case, async: true
  @moduletag :handlers

  import Mox
  setup :set_mox_from_context
  setup :verify_on_exit!

  alias BotArmyNotion.Handlers.DatabaseHandler
  alias BotArmyNotion.NotionMock

  describe "notion.database.query" do
    test "queries rows with optional filter/sorts/page_size" do
      filter = %{"property" => "Status", "select" => %{"equals" => "Active"}}

      expect(NotionMock, :query_database, fn db_id, opts ->
        assert db_id == "db1"
        assert opts[:filter] == filter
        assert opts[:page_size] == 50
        {:ok, [%{"id" => "row1"}]}
      end)

      assert {:ok, [%{"id" => "row1"}]} =
               DatabaseHandler.handle_query(
                 %{"database_id" => "db1", "filter" => filter, "page_size" => 50},
                 NotionMock
               )
    end

    test "returns validation error when database_id missing" do
      assert {:error, %{code: :validation_error}} = DatabaseHandler.handle_query(%{}, NotionMock)
    end
  end

  describe "notion.database.get" do
    test "fetches the database schema object" do
      expect(NotionMock, :get_database, fn db_id, _opts ->
        assert db_id == "db1"
        {:ok, %{"id" => "db1", "properties" => %{"Name" => %{"type" => "title"}}}}
      end)

      assert {:ok, %{"id" => "db1", "properties" => _}} =
               DatabaseHandler.handle_get(%{"database_id" => "db1"}, NotionMock)
    end

    test "returns validation error when database_id missing" do
      assert {:error, %{code: :validation_error}} = DatabaseHandler.handle_get(%{}, NotionMock)
    end
  end
end
