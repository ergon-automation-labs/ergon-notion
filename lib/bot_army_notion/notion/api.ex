defmodule BotArmyNotion.Notion.API do
  @moduledoc """
  Req-based implementation of `BotArmyNotion.Notion`.

  Talks to https://api.notion.com/v1 with `Authorization: Bearer <NOTION_TOKEN>`
  and `Notion-Version: 2022-06-28`. Handles pagination (`has_more`/`next_cursor`)
  and recursive block-tree retrieval for `get_page/2`.
  """

  @behaviour BotArmyNotion.Notion

  @base_url "https://api.notion.com/v1"
  @default_version "2022-06-28"
  @default_page_size 100
  @default_block_depth 2

  @impl true
  def get_page(page_id, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, @default_block_depth)

    with {:ok, page} <- request(:get, "/pages/#{page_id}"),
         {:ok, blocks} <- get_block_tree(page_id, max_depth) do
      {:ok, %{"page" => page, "blocks" => blocks}}
    end
  end

  @impl true
  def search(query, opts \\ []) do
    body = %{
      "query" => query,
      "page_size" => Keyword.get(opts, :page_size, @default_page_size)
    }

    body =
      case Keyword.get(opts, :filter) do
        nil -> body
        filter -> Map.put(body, "filter", filter)
      end

    paginate(:post, "/search", body)
  end

  @impl true
  def query_database(database_id, opts \\ []) do
    body =
      %{"page_size" => Keyword.get(opts, :page_size, @default_page_size)}
      |> maybe_put("filter", Keyword.get(opts, :filter))
      |> maybe_put("sorts", Keyword.get(opts, :sorts))

    paginate(:post, "/databases/#{database_id}/query", body)
  end

  @impl true
  def get_database(database_id, _opts \\ []) do
    request(:get, "/databases/#{database_id}")
  end

  # ---------------------------------------------------------------------------
  # Block tree (recursive children)
  # ---------------------------------------------------------------------------

  defp get_block_tree(block_id, depth) when depth >= 0 do
    case paginate(:get, "/blocks/#{block_id}/children", %{"page_size" => @default_page_size}) do
      {:ok, children} ->
        {:ok, attach_children(children, depth)}

      error ->
        error
    end
  end

  defp attach_children(blocks, depth) do
    Enum.map(blocks, &maybe_attach_child(&1, depth))
  end

  defp maybe_attach_child(block, depth) when is_map(block) and is_integer(depth) do
    if block["has_children"] && depth > 0 do
      attach_child_tree(block, depth)
    else
      block
    end
  end

  defp attach_child_tree(block, depth) do
    case get_block_tree(block["id"], depth - 1) do
      {:ok, sub} -> Map.put(block, "children", sub)
      _ -> block
    end
  end

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  defp paginate(method, path, payload) do
    do_paginate(method, path, payload, nil, [])
  end

  defp do_paginate(method, path, payload, cursor, acc) do
    payload = if cursor, do: Map.put(payload, "start_cursor", cursor), else: payload

    case request(method, path, payload) do
      {:ok, %{"results" => results} = body} ->
        acc = acc ++ results

        if body["has_more"] && body["next_cursor"] do
          do_paginate(method, path, payload, body["next_cursor"], acc)
        else
          {:ok, acc}
        end

      {:ok, other} ->
        {:ok, other}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # HTTP
  # ---------------------------------------------------------------------------

  defp request(:get, path, params) when is_map(params) do
    Req.get(request_base(), url: path, params: Map.to_list(params)) |> handle_response()
  end

  defp request(:post, path, body) when is_map(body) do
    Req.post(request_base(), url: path, json: body) |> handle_response()
  end

  defp request(:get, path) do
    Req.get(request_base(), url: path) |> handle_response()
  end

  defp request_base do
    case token() do
      nil ->
        nil

      token ->
        Req.new(
          base_url: @base_url,
          headers: [
            {"Authorization", "Bearer #{token}"},
            {"Notion-Version", version()}
          ]
        )
    end
  end

  defp handle_response(nil),
    do: {:error, %{status: nil, code: :not_configured, message: "NOTION_TOKEN not set"}}

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, decode(body)}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    body = decode(body)

    {:error,
     %{status: status, code: body["code"], message: body["message"] || "Notion API error"}}
  end

  defp handle_response({:error, exception}) do
    {:error, %{status: nil, code: :transport_error, message: inspect(exception)}}
  end

  defp decode(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end

  defp decode(body) when is_map(body), do: body
  defp decode(_), do: %{}

  defp token,
    do: Application.get_env(:bot_army_notion, :notion_token) || System.get_env("NOTION_TOKEN")

  defp version, do: Application.get_env(:bot_army_notion, :notion_version) || @default_version

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
