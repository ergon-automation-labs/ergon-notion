defmodule BotArmyNotion.Handlers.SearchHandler do
  @moduledoc """
  Handles `notion.search` — find Notion pages/databases the integration can see.

  Params:
    - `query` (required) — search string (matches titles)
    - `filter` (optional) — e.g. `%{"value" => "page", "property" => "object"}`
    - `page_size` (optional, default 100)
  """

  def handle(%{"query" => query} = params, client) when is_binary(query) do
    opts =
      []
      |> maybe(:filter, Map.get(params, "filter"))
      |> maybe(:page_size, Map.get(params, "page_size"))

    client.search(query, opts)
  end

  def handle(_params, _client) do
    {:error, %{status: nil, code: :validation_error, message: "missing required field: query"}}
  end

  defp maybe(opts, _key, nil), do: opts
  defp maybe(opts, key, value), do: Keyword.put(opts, key, value)
end
