defmodule BotArmyNotion.Handlers.DatabaseHandler do
  @moduledoc """
  Handles `notion.database.query` and `notion.database.get`.

  `notion.database.query` params:
    - `database_id` (required)
    - `filter` (optional) — Notion filter object
    - `sorts` (optional) — Notion sort array
    - `page_size` (optional, default 100)

  `notion.database.get` params:
    - `database_id` (required) — returns the database object incl. property schema
  """

  def handle_query(%{"database_id" => database_id} = params, client)
      when is_binary(database_id) do
    opts =
      []
      |> maybe(:filter, Map.get(params, "filter"))
      |> maybe(:sorts, Map.get(params, "sorts"))
      |> maybe(:page_size, Map.get(params, "page_size"))

    client.query_database(database_id, opts)
  end

  def handle_query(_params, _client) do
    {:error,
     %{status: nil, code: :validation_error, message: "missing required field: database_id"}}
  end

  def handle_get(%{"database_id" => database_id}, client) when is_binary(database_id) do
    client.get_database(database_id, [])
  end

  def handle_get(_params, _client) do
    {:error,
     %{status: nil, code: :validation_error, message: "missing required field: database_id"}}
  end

  defp maybe(opts, _key, nil), do: opts
  defp maybe(opts, key, value), do: Keyword.put(opts, key, value)
end
