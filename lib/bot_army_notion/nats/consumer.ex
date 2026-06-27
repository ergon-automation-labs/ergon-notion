defmodule BotArmyNotion.NATS.Consumer do
  @moduledoc """
  NATS message consumer for the Notion bot.

  Subscribes to `notion.*` request/reply subjects and routes them to handlers,
  returning standardized `BotArmyRuntime.NATS.Reply` envelopes. The Notion API
  client is injected (default `BotArmyNotion.Notion.API`; tests use a Mox mock
  configured via `Application.put_env(:bot_army_notion, :notion_client, ...)`).
  """

  use GenServer
  require Logger

  @reconnect_delay_ms 5000
  @version Mix.Project.config()[:version]

  @subjects [
    %{
      subject: "notion.page.get",
      type: :request_reply,
      description: "Get a Notion page + its recursive block tree"
    },
    %{
      subject: "notion.search",
      type: :request_reply,
      description: "Search Notion pages/databases by title"
    },
    %{
      subject: "notion.database.query",
      type: :request_reply,
      description: "Query rows from a Notion database"
    },
    %{
      subject: "notion.database.get",
      type: :request_reply,
      description: "Get a Notion database object + property schema"
    }
  ]

  @subject_strings Enum.map(@subjects, & &1.subject)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("[Notion] Starting NATS consumer")

    state = %{
      subscriptions: [],
      conn: nil,
      client: Keyword.get(opts, :notion_client, default_client()),
      opts: opts
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case GenServer.call(BotArmyRuntime.NATS.Connection, :get_connection, 5000) do
      {:ok, conn} ->
        BotArmyRuntime.NATS.Connection.subscribe_to_status()
        Logger.info("[Notion] Connected to NATS, subscribing to topics")

        subscriptions =
          @subject_strings
          |> Enum.map(fn subject ->
            case Gnat.sub(conn, self(), subject) do
              {:ok, sub} ->
                Logger.info("[Notion] Subscribed to #{subject}")
                sub

              {:error, reason} ->
                Logger.error("[Notion] Failed to subscribe to #{subject}: #{inspect(reason)}")
                nil
            end
          end)
          |> Enum.filter(&(not is_nil(&1)))

        BotArmyRuntime.Registry.register("notion", @subjects, @version)

        {:noreply, %{state | subscriptions: subscriptions, conn: conn}}

      {:error, _reason} ->
        Logger.warning("[Notion] NATS connection not ready, will retry")
        Process.send_after(self(), :connect_retry, @reconnect_delay_ms)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:connect_retry, state) do
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    BotArmyRuntime.Tracing.with_consumer_span(msg.topic, Map.get(msg, :headers), fn ->
      if msg.reply_to do
        route_request(msg, state)
      else
        Logger.debug("[Notion] Ignoring pub/sub on #{msg.topic} (no reply_to)")
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:nats, :disconnected}, state) do
    Logger.warning("[Notion] Disconnected from NATS, will reconnect")
    Process.send_after(self(), :connect_retry, @reconnect_delay_ms)
    {:noreply, %{state | subscriptions: [], conn: nil}}
  end

  @impl true
  def handle_info({:nats, :connected}, state) do
    Logger.info("[Notion] Reconnected to NATS, re-subscribing")
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info(:reconnect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  # ---------------------------------------------------------------------------
  # Routing
  # ---------------------------------------------------------------------------

  defp route_request(msg, state) do
    result =
      with {:ok, params} <- decode_body(msg.body) do
        route(msg.topic, params, state.client)
      end

    reply(state.conn, msg.reply_to, result)
  end

  defp route("notion.page.get", params, client),
    do: BotArmyNotion.Handlers.PageHandler.handle(params, client)

  defp route("notion.search", params, client),
    do: BotArmyNotion.Handlers.SearchHandler.handle(params, client)

  defp route("notion.database.query", params, client),
    do: BotArmyNotion.Handlers.DatabaseHandler.handle_query(params, client)

  defp route("notion.database.get", params, client),
    do: BotArmyNotion.Handlers.DatabaseHandler.handle_get(params, client)

  defp route(topic, _params, _client) do
    {:error, %{status: nil, code: :unknown_subject, message: "unknown subject: #{topic}"}}
  end

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, _} ->
        {:error, %{status: nil, code: :validation_error, message: "invalid JSON body"}}
    end
  end

  defp decode_body(body) when is_map(body), do: {:ok, body}

  defp decode_body(_),
    do: {:error, %{status: nil, code: :validation_error, message: "empty body"}}

  defp reply(conn, reply_to, {:ok, data}) do
    payload = BotArmyRuntime.NATS.Reply.ok(data)
    if conn, do: Gnat.pub(conn, reply_to, payload)
  end

  defp reply(conn, reply_to, {:error, %{message: message, code: code}}) do
    payload = BotArmyRuntime.NATS.Reply.error(message, code || :error)
    if conn, do: Gnat.pub(conn, reply_to, payload)
  end

  defp reply(conn, reply_to, {:error, reason}) do
    payload = BotArmyRuntime.NATS.Reply.error(inspect(reason), :error)
    if conn, do: Gnat.pub(conn, reply_to, payload)
  end

  defp default_client,
    do: Application.get_env(:bot_army_notion, :notion_client, BotArmyNotion.Notion.API)
end
