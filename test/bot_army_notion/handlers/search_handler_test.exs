defmodule BotArmyNotion.Handlers.SearchHandlerTest do
  use ExUnit.Case, async: true
  @moduletag :handlers

  import Mox
  setup :set_mox_from_context
  setup :verify_on_exit!

  alias BotArmyNotion.Handlers.SearchHandler
  alias BotArmyNotion.NotionMock

  describe "notion.search" do
    test "searches with query only" do
      expect(NotionMock, :search, fn query, opts ->
        assert query == "Ergon"
        assert Keyword.get(opts, :filter) == nil
        {:ok, [%{"object" => "page"}]}
      end)

      assert {:ok, [%{"object" => "page"}]} =
               SearchHandler.handle(%{"query" => "Ergon"}, NotionMock)
    end

    test "forwards filter and page_size when provided" do
      filter = %{"value" => "database", "property" => "object"}

      expect(NotionMock, :search, fn query, opts ->
        assert query == "labs"
        assert opts[:filter] == filter
        assert opts[:page_size] == 25
        {:ok, []}
      end)

      SearchHandler.handle(
        %{"query" => "labs", "filter" => filter, "page_size" => 25},
        NotionMock
      )
    end

    test "returns validation error when query missing" do
      assert {:error, %{code: :validation_error}} = SearchHandler.handle(%{}, NotionMock)
    end
  end
end
