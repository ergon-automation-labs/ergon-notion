defmodule BotArmyNotion.Notion do
  @moduledoc """
  Notion REST API behaviour.

  Defines a small read surface over the Notion API so handlers can be tested
  with a Mox mock (`BotArmyNotion.NotionMock`) instead of hitting the network.

  All callbacks return `{:ok, data}` or `{:error, reason}` where `reason` is a map
  with `:status`, `:code`, `:message` (Notion error envelope) or a transport term.
  """

  @type reason :: %{status: pos_integer() | nil, code: term(), message: String.t()}

  @callback get_page(page_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, reason()}
  @callback search(query :: String.t(), opts :: keyword()) ::
              {:ok, [map()]} | {:error, reason()}
  @callback query_database(database_id :: String.t(), opts :: keyword()) ::
              {:ok, [map()]} | {:error, reason()}
  @callback get_database(database_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, reason()}
end
