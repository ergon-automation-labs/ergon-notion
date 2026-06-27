defmodule BotArmyNotion.Handlers.PageHandler do
  @moduledoc """
  Handles `notion.page.get` — fetch a Notion page + its recursive block tree.

  Params:
    - `page_id` (required) — Notion page id (32-char hex, with or without hyphens)
    - `max_depth` (optional, default 2) — how deep to recurse block children
  """

  @default_max_depth 2

  def handle(%{"page_id" => page_id} = params, client) when is_binary(page_id) do
    max_depth = Map.get(params, "max_depth", @default_max_depth)
    client.get_page(page_id, max_depth: max_depth)
  end

  def handle(_params, _client) do
    {:error, %{status: nil, code: :validation_error, message: "missing required field: page_id"}}
  end
end
