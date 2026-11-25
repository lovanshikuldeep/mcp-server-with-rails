# MCP with Blog

A Rails 8.1 blog (create, list, show, edit and delete posts) backed by PostgreSQL,
plus an [MCP](https://modelcontextprotocol.io) server that lets AI assistants such
as Claude Desktop, Cursor and VS Code manage the same posts.

- **Web app:** `Post` scaffold with `title` and `body`, served at `/`.
- **MCP server:** five tools (`list_posts`, `get_post`, `create_post`, `update_post`,
  `delete_post`) that use the same `Post` model, so validations apply everywhere.
- **Transport:** stdio. The AI client starts `bin/mcp_server` as a subprocess.

## Requirements

- Ruby 3.4.7 (see `.ruby-version`) and Bundler
- PostgreSQL (9.3 or newer) running locally or reachable over the network

## Setup

```bash
bundle install
```

### Database

`config/database.yml` reads its connection settings from environment variables:

| Variable            | Default     |
| ------------------- | ----------- |
| `DATABASE_HOST`     | `localhost` |
| `DATABASE_PORT`     | `5432`      |
| `DATABASE_USERNAME` | `postgres`  |
| `DATABASE_PASSWORD` | (none)      |

Set them if your PostgreSQL differs from the defaults, then create and migrate the databases:

```bash
export DATABASE_PASSWORD=your-password   # only if your server needs one
bin/rails db:create db:migrate
```

Databases are named `mcp_with_blog_development`, `mcp_with_blog_test` and, in
production, `mcp_with_blog_production` plus `_cache`, `_queue` and `_cable`.

### Run the app

```bash
bin/rails server
```

Open <http://localhost:3000> to list, create, edit and delete posts.

### Run the tests

```bash
bin/rails test
```

## MCP server

`bin/mcp_server` loads the Rails app and serves the tools in `app/mcp/` over stdio.
It runs in the `development` environment unless `RAILS_ENV` is set, so make sure
the database is created and migrated first (see above).

| Tool          | Arguments                                | What it does                        |
| ------------- | ---------------------------------------- | ----------------------------------- |
| `list_posts`  | `limit` (optional, 1-100, default 20)    | Lists posts, newest first           |
| `get_post`    | `id`                                     | Returns one post                    |
| `create_post` | `title`, `body`                          | Creates a post                      |
| `update_post` | `id`, `title` and/or `body`              | Updates a post                      |
| `delete_post` | `id`                                     | Permanently deletes a post          |

Try it without any AI client by piping JSON-RPC messages into the script:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | bundle exec bin/mcp_server
```

> **Security:** the server has no authentication and `delete_post` is destructive.
> Only connect it to clients you trust, on a machine you control.

## Connect Claude Desktop

Claude Desktop reads MCP servers from `claude_desktop_config.json`, a file outside
this repository.

| OS      | Config file location                                              |
| ------- | ----------------------------------------------------------------- |
| Linux   | `~/.config/Claude/claude_desktop_config.json`                     |
| macOS   | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Windows | `%APPDATA%\Claude\claude_desktop_config.json`                     |

### 1. Prepare the project

Complete the [Setup](#setup) steps first, so `bundle install` has run and the
development database exists and is migrated.

### 2. Find your paths

Claude Desktop starts MCP servers with a minimal environment: it does not load your
shell profile, so version managers such as RVM, rbenv or asdf are not active. Because
of that, use absolute paths. Run these from the project directory:

```bash
pwd                 # project directory
which ruby          # full path to the Ruby binary
gem env home        # GEM_HOME
gem env gempath     # GEM_PATH (colon-separated list)
```

### 3. Add the server to the config

Open `claude_desktop_config.json` and add an `mcpServers` entry. If the file already
has other settings, keep them and add `mcpServers` as another top-level key. If
`mcpServers` already exists, add `mcp_with_blog` inside it.

```json
{
  "mcpServers": {
    "mcp_with_blog": {
      "command": "/home/you/.rvm/rubies/ruby-3.4.7/bin/ruby",
      "args": ["/home/you/mcp_demo/mcp_with_blog/bin/mcp_server"],
      "env": {
        "BUNDLE_GEMFILE": "/home/you/mcp_demo/mcp_with_blog/Gemfile",
        "GEM_HOME": "/home/you/.rvm/gems/ruby-3.4.7",
        "GEM_PATH": "/home/you/.rvm/gems/ruby-3.4.7:/home/you/.rvm/gems/ruby-3.4.7@global"
      }
    }
  }
}
```

Replace every path with the values from step 2:

- `command` is the output of `which ruby`. If it points to a shim (rbenv or asdf), use
  the real binary instead, for example `rbenv which ruby`.
- `args` is the project directory plus `/bin/mcp_server`.
- `BUNDLE_GEMFILE` is the project directory plus `/Gemfile`.
- `GEM_HOME` and `GEM_PATH` come from `gem env home` and `gem env gempath`. Without
  them, Bundler fails with "Could not find rails-... in locally installed gems".
- If your PostgreSQL needs a password or a non-default host, add `DATABASE_HOST`,
  `DATABASE_USERNAME` and `DATABASE_PASSWORD` to `env`. Claude Desktop does not
  inherit variables from your shell.

Check that the file is still valid JSON before restarting:

```bash
python3 -m json.tool ~/.config/Claude/claude_desktop_config.json > /dev/null && echo valid
```

### 4. Restart Claude Desktop completely

Closing the window is not enough. Quit the app (**File > Quit** or `Ctrl+Q`) and open
it again. The config is only read at startup.

### 5. Verify the connection

- Open a new chat and click the tools icon near the message box. `mcp_with_blog` should
  appear with its five tools.
- Go to **Settings > Developer**. The server should be listed as running.
- Try a prompt such as "List my blog posts" or "Create a blog post about Rails and MCP".
  Claude asks for approval the first time it uses each tool.
- Created posts also appear in the web app at <http://localhost:3000>.

### Troubleshooting

Claude Desktop writes one log per server. On Linux it is
`~/.config/Claude/logs/mcp-server-mcp_with_blog.log` (on macOS, `~/Library/Logs/Claude/`).

| Symptom                                       | Likely cause and fix                                                                                       |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Server missing from the tools menu            | The app was not fully restarted, or the JSON is invalid. Quit and reopen it, then validate the file.      |
| `Could not find rails-... in locally installed gems` | `GEM_HOME` or `GEM_PATH` is missing or wrong. Set them from `gem env`.                              |
| `command not found` or `ENOENT`               | `command` is not an absolute path to a real Ruby binary.                                                   |
| `PG::ConnectionBad` or `database ... does not exist` | PostgreSQL is not running, the database was not created, or `DATABASE_*` is missing from `env`.      |
| Tools return errors about a missing table     | Run `bin/rails db:migrate` for the `development` environment.                                              |

Test the exact command Claude Desktop runs, with a minimal environment, from a terminal:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_posts","arguments":{"limit":1}}}' \
| env -i HOME="$HOME" PATH=/usr/bin:/bin \
    BUNDLE_GEMFILE="$PWD/Gemfile" \
    GEM_HOME="$(gem env home)" GEM_PATH="$(gem env gempath)" \
    "$(which ruby)" bin/mcp_server
```

If this prints two JSON responses, the same values in `claude_desktop_config.json` will work.

## Connect Cursor

This repo includes `.cursor/mcp.json`. Open the project in Cursor, enable
`mcp_with_blog` under **Settings > MCP**, and reload the window if it does not appear.
The file uses `"cwd"` with an absolute path, so update it if the project lives somewhere else.

## Connect VS Code

This repo includes `.vscode/mcp.json`, which uses `${workspaceFolder}` and works from
any location. Open the project in VS Code, open `.vscode/mcp.json` and click **Start**
above `mcp_with_blog`, then use the tools from Copilot Chat in **Agent** mode. This
needs a VS Code version with MCP support and a chat extension such as GitHub Copilot.

## Project layout

| Path                    | Purpose                                              |
| ----------------------- | ---------------------------------------------------- |
| `app/models/post.rb`    | `Post` model and validations                         |
| `app/controllers/posts_controller.rb`, `app/views/posts/` | Web UI for posts      |
| `app/mcp/`              | MCP tools (`*_tool.rb`) and `BlogServer`             |
| `bin/mcp_server`        | stdio entry point for MCP clients                    |
| `.cursor/mcp.json`      | Cursor MCP configuration                             |
| `.vscode/mcp.json`      | VS Code MCP configuration                            |
| `config/database.yml`   | PostgreSQL configuration                             |
