defmodule Shazam.CLI.Formatter do
  @moduledoc "Terminal output formatting for Shazam CLI."
  @version Mix.Project.config()[:version] || "0.0.0"

  # --- Colors ---

  def header(text) do
    IO.puts([IO.ANSI.bright(), IO.ANSI.cyan(), "\n  #{text}", IO.ANSI.reset()])
    IO.puts([IO.ANSI.cyan(), "  #{String.duplicate("─", String.length(text) + 2)}", IO.ANSI.reset()])
  end

  def success(text), do: IO.puts([IO.ANSI.green(), "  ✓ ", IO.ANSI.reset(), text])
  def error(text), do: IO.puts([IO.ANSI.red(), "  ✗ ", IO.ANSI.reset(), text])
  def warning(text), do: IO.puts([IO.ANSI.yellow(), "  ⚠ ", IO.ANSI.reset(), text])
  def info(text), do: IO.puts([IO.ANSI.blue(), "  ● ", IO.ANSI.reset(), text])
  def dim(text), do: IO.puts([IO.ANSI.faint(), "  #{text}", IO.ANSI.reset()])

  # --- Table ---

  def table(headers, rows) do
    all = [headers | rows]
    widths = headers
      |> Enum.with_index()
      |> Enum.map(fn {_, i} ->
        all |> Enum.map(&(Enum.at(&1, i, "") |> to_string() |> String.length())) |> Enum.max()
      end)

    header_line = headers
      |> Enum.zip(widths)
      |> Enum.map(fn {h, w} -> String.pad_trailing(to_string(h), w) end)
      |> Enum.join("  ")

    separator = widths |> Enum.map(&String.duplicate("─", &1)) |> Enum.join("──")

    IO.puts([IO.ANSI.faint(), "  ", header_line, IO.ANSI.reset()])
    IO.puts([IO.ANSI.faint(), "  ", separator, IO.ANSI.reset()])

    Enum.each(rows, fn row ->
      line = row
        |> Enum.zip(widths)
        |> Enum.map(fn {cell, w} -> String.pad_trailing(to_string(cell), w) end)
        |> Enum.join("  ")
      IO.puts("  #{line}")
    end)

    IO.puts("")
  end

  # --- Org Tree ---

  def tree(nodes, indent \\ "") do
    total = length(nodes)
    nodes
    |> Enum.with_index(1)
    |> Enum.each(fn {node, idx} ->
      is_last = idx == total
      connector = if is_last, do: "└── ", else: "├── "
      child_prefix = if is_last, do: "    ", else: "│   "

      status = status_dot(node[:status])
      domain = if node[:domain], do: [IO.ANSI.faint(), " [#{node[:domain]}]", IO.ANSI.reset()], else: []
      role = [IO.ANSI.faint(), " (#{node[:role]})", IO.ANSI.reset()]

      IO.puts(["  ", indent, connector, status, " ", to_string(node[:name]), role, domain])

      subs = node[:subordinates] || []
      if subs != [] do
        tree(subs, indent <> child_prefix)
      end
    end)
  end

  # --- Status helpers ---

  def status_dot(nil), do: [IO.ANSI.faint(), "○", IO.ANSI.reset()]
  def status_dot("idle"), do: [IO.ANSI.yellow(), "○", IO.ANSI.reset()]
  def status_dot("working"), do: [IO.ANSI.green(), "●", IO.ANSI.reset()]
  def status_dot("thinking"), do: [IO.ANSI.blue(), "●", IO.ANSI.reset()]
  def status_dot("error"), do: [IO.ANSI.red(), "●", IO.ANSI.reset()]
  def status_dot(_), do: [IO.ANSI.faint(), "○", IO.ANSI.reset()]

  def status_text("running"), do: [IO.ANSI.green(), "running", IO.ANSI.reset()]
  def status_text("paused"), do: [IO.ANSI.yellow(), "paused", IO.ANSI.reset()]
  def status_text("idle"), do: [IO.ANSI.faint(), "idle", IO.ANSI.reset()]
  def status_text(other), do: to_string(other || "unknown")

  def progress_bar(used, total) when total > 0 do
    pct = min(round(used / total * 100), 100)
    filled = round(pct / 10)
    empty = 10 - filled
    color = cond do
      pct > 90 -> IO.ANSI.red()
      pct > 70 -> IO.ANSI.yellow()
      true -> IO.ANSI.green()
    end
    [color, String.duplicate("█", filled), IO.ANSI.faint(), String.duplicate("░", empty),
     IO.ANSI.reset(), " #{pct}%"]
  end

  def progress_bar(_, _), do: [IO.ANSI.faint(), "░░░░░░░░░░ 0%", IO.ANSI.reset()]

  # --- Event log line ---

  def log_event(event) do
    ts = Shazam.CLI.Formatter.local_time_string()
    type = event[:event] || event["event"] || "unknown"
    agent = event[:agent] || event["agent"] || event["assigned_to"] || ""
    title = event[:title] || event["title"] || event[:task_id] || event["task_id"] || ""

    {icon, color} = event_style(type)

    IO.puts([
      IO.ANSI.faint(), ts, " ", IO.ANSI.reset(),
      color, "[#{agent}]", IO.ANSI.reset(),
      "  #{icon} ",
      format_event_text(type, title, event)
    ])
  end

  defp event_style("task_created"), do: {"📋", IO.ANSI.blue()}
  defp event_style("task_started"), do: {"🔧", IO.ANSI.yellow()}
  defp event_style("task_completed"), do: {"✅", IO.ANSI.green()}
  defp event_style("task_failed"), do: {"❌", IO.ANSI.red()}
  defp event_style("task_awaiting_approval"), do: {"⚠️ ", IO.ANSI.yellow()}
  defp event_style("task_approved"), do: {"✅", IO.ANSI.green()}
  defp event_style("task_rejected"), do: {"🚫", IO.ANSI.red()}
  defp event_style("agent_output"), do: {"💬", IO.ANSI.cyan()}
  defp event_style("ralph_resumed"), do: {"▶️ ", IO.ANSI.green()}
  defp event_style("ralph_paused"), do: {"⏸️ ", IO.ANSI.yellow()}
  defp event_style("tool_use"), do: {"🔧", IO.ANSI.magenta()}
  defp event_style("task_killed"), do: {"💀", IO.ANSI.red()}
  defp event_style("task_paused"), do: {"⏸️ ", IO.ANSI.yellow()}
  defp event_style(_), do: {"  ", IO.ANSI.faint()}

  defp format_event_text("task_created", title, event) do
    to = event[:assigned_to] || event["assigned_to"] || ""
    "Created: #{title}" <> if(to != "", do: " → #{to}", else: "")
  end
  defp format_event_text("task_completed", title, _), do: "Completed: #{title}"
  defp format_event_text("task_failed", title, _), do: "Failed: #{title}"
  defp format_event_text("task_started", title, _), do: "Started: #{title}"
  defp format_event_text("agent_output", _, event) do
    text = event[:text] || event["text"] || ""
    String.slice(to_string(text), 0, 120)
  end
  defp format_event_text(type, title, _), do: "#{type}: #{title}"

  # --- Divider ---

  def divider do
    IO.puts([IO.ANSI.faint(), "  ", String.duplicate("─", 60), IO.ANSI.reset()])
  end

  # --- Banner ---

  def banner do
    animate_lightning()
  end

  # ── Lightning strike animation ──────────────────────────────

  @logo_lines [
    "       ███████╗██╗  ██╗ █████╗ ███████╗ █████╗ ███╗   ███╗",
    "       ██╔════╝██║  ██║██╔══██╗╚══███╔╝██╔══██╗████╗ ████║",
    "       ███████╗███████║███████║  ███╔╝ ███████║██╔████╔██║",
    "       ╚════██║██╔══██║██╔══██║ ███╔╝  ██╔══██║██║╚██╔╝██║",
    "       ███████║██║  ██║██║  ██║███████╗██║  ██║██║ ╚═╝ ██║",
    "       ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝"
  ]

  def banner_static do
    Enum.each(@logo_lines, fn line ->
      IO.puts([IO.ANSI.bright(), IO.ANSI.yellow(), line, IO.ANSI.reset()])
    end)
    IO.puts([IO.ANSI.faint(), "       AI Agent Orchestrator v#{@version}  •  shazam.dev\n", IO.ANSI.reset()])
  end

  @bolt_full [
    "                    ██▄",
    "                   ██",
    "                  ██",
    "                 ████████▄",
    "                    ██",
    "                   ██",
    "                  ██",
    "                 ████████▄",
    "                    ██",
    "                   ██",
    "                  ▀▀"
  ]

  defp animate_lightning do
    IO.write("\e[?25l")  # Hide cursor
    {rows, cols} = terminal_size()

    # Phase 1: Lightning bolt falls line by line (yellow)
    IO.write("\e[2J\e[1;1H\n")
    Enum.each(@bolt_full, fn line ->
      IO.puts([IO.ANSI.yellow(), IO.ANSI.bright(), line, IO.ANSI.reset()])
      Process.sleep(50)
    end)
    Process.sleep(100)

    # Phase 2: Flash — invert colors briefly
    IO.write("\e[7m")  # Reverse video
    Enum.each(1..rows, fn r ->
      IO.write("\e[#{r};1H#{String.duplicate(" ", cols)}")
    end)
    Process.sleep(80)
    IO.write("\e[27m\e[0m")  # Reset reverse + all attrs

    # Phase 3: Logo appears in golden yellow (Shazam's lightning)
    # Clear every line manually to avoid scroll region issues
    Enum.each(1..rows, fn r ->
      IO.write("\e[#{r};1H\e[2K")
    end)
    IO.write("\e[1;1H\n")
    Enum.each(@logo_lines, fn line ->
      IO.puts([IO.ANSI.bright(), IO.ANSI.yellow(), line, IO.ANSI.reset()])
    end)
    IO.puts([IO.ANSI.faint(), "       AI Agent Orchestrator v#{@version}  •  shazam.dev\n", IO.ANSI.reset()])

    IO.write("\e[?25h")  # Show cursor
  end

  def local_time_string do
    Calendar.strftime(NaiveDateTime.local_now(), "%H:%M:%S")
  end

  def to_local_time_string(%DateTime{} = dt) do
    now_utc = NaiveDateTime.utc_now()
    now_local = NaiveDateTime.local_now()
    offset = NaiveDateTime.diff(now_local, now_utc, :second)
    Calendar.strftime(DateTime.add(dt, offset, :second), "%H:%M:%S")
  end

  def to_local_time_string(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M:%S")
  end

  def to_local_time_string(dt) when is_binary(dt), do: dt
  def to_local_time_string(_), do: ""

  def print_welcome(:repl) do
    IO.puts([IO.ANSI.faint(), "       AI Agent Orchestrator v#{@version}  •  shazam.dev\n", IO.ANSI.reset()])
  end
  def print_welcome(:server, port) do
    IO.puts([IO.ANSI.faint(), "       Starting HTTP server on port #{port}...", IO.ANSI.reset()])
  end

  defp terminal_size do
    rows = case :io.rows() do {:ok, r} -> r; _ -> 24 end
    cols = case :io.columns() do {:ok, c} -> c; _ -> 80 end
    {rows, cols}
  end
end
