import Config

# Notion API credentials — provision via env, never commit.
# Create an internal integration at https://www.notion.so/my-integrations,
# share the target page(s)/database(s) with it, then export NOTION_TOKEN.
config :bot_army_notion,
  notion_token: System.get_env("NOTION_TOKEN"),
  notion_version: System.get_env("NOTION_VERSION", "2022-06-28")
