defmodule BotArmyNotion.Handlers.PageHandlerTest do
  use ExUnit.Case, async: true
  @moduletag :handlers

  import Mox
  setup :set_mox_from_context
  setup :verify_on_exit!

  alias BotArmyNotion.Handlers.PageHandler
  alias BotArmyNotion.NotionMock

  describe "notion.page.get" do
    test "fetches page + block tree with default max_depth" do
      expect(NotionMock, :get_page, fn page_id, opts ->
        assert page_id == "abc123"
        assert opts[:max_depth] == 2
        {:ok, %{"page" => %{"id" => "abc123"}, "blocks" => []}}
      end)

      assert {:ok, %{"page" => %{"id" => "abc123"}}} =
               PageHandler.handle(%{"page_id" => "abc123"}, NotionMock)
    end

    test "passes through max_depth when provided" do
      expect(NotionMock, :get_page, fn _page_id, opts ->
        assert opts[:max_depth] == 5
        {:ok, %{"page" => %{}, "blocks" => []}}
      end)

      PageHandler.handle(%{"page_id" => "p", "max_depth" => 5}, NotionMock)
    end

    test "returns validation error when page_id missing" do
      assert {:error, %{code: :validation_error}} = PageHandler.handle(%{}, NotionMock)
    end
  end
end
