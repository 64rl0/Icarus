# ======================================================================
# MODULE DETAILS
# This section provides metadata about the module, including its
# creation date, author, copyright information, and a brief description
# of the module's purpose and functionality.
# ======================================================================

#   __|    \    _ \  |      _ \   __| __ __| __ __|
#  (      _ \     /  |     (   | (_ |    |      |
# \___| _/  _\ _|_\ ____| \___/ \___|   _|     _|

# src/icarus/handlers/builder_handler/report_generator.py
# Created 2/28/26 - 10:02 AM UK Time (London) by carlogtt
# Copyright (c) Amazon.com Inc. All Rights Reserved.
# AMAZON.COM CONFIDENTIAL

"""
This module ...
"""

# ======================================================================
# EXCEPTIONS
# This section documents any exceptions made code or quality rules.
# These exceptions may be necessary due to specific coding requirements
# or to bypass false positives.
# ======================================================================
#

# ======================================================================
# IMPORTS
# Importing required libraries and modules for the application.
# ======================================================================

# Standard Library Imports
import datetime
import json
import pathlib
import re
from string import Template
from typing import Any

# Local Application Imports
from icarus import config

# END IMPORTS
# ======================================================================


# List of public names in the module
__all__ = [
    'generate_report',
]

# Setting up logger for current module
module_logger = config.master_logger.get_child_logger(__name__)


def generate_report(project_root: pathlib.Path) -> None:
    """
    Generate the builder HTML report from the trace log.

    :param project_root: Path to the project root directory.
    """

    control_plane = project_root / config.ICARUS_CONTROL_PLANE_DIRNAME
    log_dir = control_plane / config.ICARUS_LOG_DIRNAME
    report_dir = control_plane / config.ICARUS_REPORT_DIRNAME
    report_path = report_dir / config.ICARUS_REPORT_FILENAME
    trace_path = log_dir / config.ICARUS_TRACE_LOG_FILENAME

    entries = _read_trace_log(trace_path)
    html = _render_report(entries, log_dir)

    report_path.write_text(html, encoding='utf-8')

    module_logger.debug(f"Report generated at {report_path}")


def _render_report(entries: list[dict[str, Any]], log_dir: pathlib.Path) -> str:
    """
    Render the full HTML report from trace entries.

    :param entries: List of trace entry dictionaries.
    :param log_dir: Path to the log directory.
    :return: Complete HTML string.
    """

    stats = _compute_stats(entries)
    duration_bars = _build_duration_bars(entries)
    table_rows = _build_run_table_rows(entries, log_dir)

    now = datetime.datetime.now(datetime.timezone.utc).astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')

    template = Template(_HTML_TEMPLATE)

    response = template.safe_substitute(
        report_generated=now,
        total_runs=stats['total'],
        passed_runs=stats['passed'],
        failed_runs=stats['failed'],
        warned_runs=stats['warned'],
        success_rate=stats['success_rate'],
        avg_duration=stats['avg_duration'],
        min_duration=stats['min_duration'],
        max_duration=stats['max_duration'],
        min_duration_run_id=stats['min_duration_run_id'],
        max_duration_run_id=stats['max_duration_run_id'],
        table_rows=table_rows,
        duration_bars=duration_bars,
    )

    return response


def _compute_stats(entries: list[dict[str, Any]]) -> dict[str, Any]:
    """
    Compute aggregate statistics from trace entries.

    :param entries: List of trace entry dictionaries.
    :return: Dictionary of computed statistics.
    """

    total = len(entries)
    passed = sum(1 for e in entries if e.get('return_code') == 0)
    failed = sum(1 for e in entries if e.get('return_code', 0) not in (0, 2))
    warned = sum(1 for e in entries if e.get('return_code') == 2)
    durations = [e.get('duration_seconds', 0) for e in entries]
    avg_duration = sum(durations) / total if total else 0
    max_duration = max(durations) if durations else 0
    min_duration = min(durations) if durations else 0
    max_duration_run_id = ''
    min_duration_run_id = ''
    if entries:
        max_entry = max(entries, key=lambda e: e.get('duration_seconds', 0))
        min_entry = min(entries, key=lambda e: e.get('duration_seconds', 0))
        max_duration_run_id = max_entry.get('run_id', '')
        min_duration_run_id = min_entry.get('run_id', '')
    success_rate = round((passed / total) * 100, 1) if total else 0

    response = {
        'total': total,
        'passed': passed,
        'failed': failed,
        'warned': warned,
        'avg_duration': _format_duration(avg_duration),
        'max_duration': _format_duration(max_duration),
        'min_duration': _format_duration(min_duration),
        'max_duration_run_id': max_duration_run_id,
        'min_duration_run_id': min_duration_run_id,
        'success_rate': success_rate,
    }

    return response


def _build_duration_bars(entries: list[dict[str, Any]]) -> str:
    """
    Build a simple CSS bar chart of run durations (last 100 runs).

    :param entries: List of trace entry dictionaries.
    :return: HTML string of the duration chart.
    """

    recent = entries[-100:]

    if not recent:
        return '<p class="empty">No runs recorded yet.</p>'

    max_dur = max(e.get('duration_seconds', 0.001) for e in recent)
    if max_dur == 0:
        max_dur = 1

    # Extract date labels for first and last run
    first_label = ''
    last_label = ''
    try:
        dt = datetime.datetime.fromisoformat(recent[0].get('start_time', ''))
        first_label = dt.strftime('%Y-%m-%d %H:%M')
    except (ValueError, TypeError):
        pass
    try:
        dt = datetime.datetime.fromisoformat(recent[-1].get('start_time', ''))
        last_label = dt.strftime('%Y-%m-%d %H:%M')
    except (ValueError, TypeError):
        pass

    bars: list[str] = []
    for entry in recent:
        run_id = entry.get('run_id', '')
        duration = entry.get('duration_seconds', 0)
        return_code = entry.get('return_code', 0)
        pct = max((duration / max_dur) * 100, 2)

        if return_code == 0:
            color_class = 'bar-pass'
        elif return_code == 2:
            color_class = 'bar-warn'
        else:
            color_class = 'bar-fail'

        try:
            dt = datetime.datetime.fromisoformat(entry.get('start_time', ''))
            tooltip = f"{dt.strftime('%m/%d %H:%M')} - {duration}s"
        except (ValueError, TypeError):
            tooltip = f"{duration}s"

        bars.append(
            f'<div class="bar {color_class}" style="height:{pct}%"'
            f' title="{tooltip}" data-run-id="{run_id}"'
            f' onclick="scrollToRun(\'{run_id}\')"></div>'
        )

    bars_html = '\n'.join(bars)

    response = (
        '<div class="chart-labels">'
        f'<span class="chart-label-left">{first_label}</span>'
        f'<span class="chart-label-right">{last_label}</span>'
        '</div>'
        '<div class="chart-bars">'
        f'{bars_html}'
        '</div>'
    )

    return response


def _build_run_table_rows(entries: list[dict[str, Any]], log_dir: pathlib.Path) -> str:
    """
    Build HTML table rows for each trace entry (most recent first).

    :param entries: List of trace entry dictionaries.
    :param log_dir: Path to the log directory.
    :return: HTML string of table rows.
    """

    rows: list[str] = []

    for entry in reversed(entries):
        run_id = entry.get('run_id', '')
        command = _extract_initial_command(entry)
        return_code = entry.get('return_code', '')
        start_time = entry.get('start_time', '')
        duration = entry.get('duration_seconds', '')
        cwd = entry.get('cwd', '')
        command_args = entry.get('command_args', [])

        if return_code == 0:
            status_class = 'passed'
            status_label = 'PASS'
        elif return_code == 2:
            status_class = 'warned'
            status_label = 'WARN'
        else:
            status_class = 'failed'
            status_label = 'FAIL'

        # Link to log file for failed runs
        log_file = log_dir / f"{run_id}.log"
        if log_file.is_file():
            log_link = (
                f'<a href="../{config.ICARUS_LOG_DIRNAME}/{run_id}.log"'
                ' class="log-link" target="_blank">view log</a>'
            )
        else:
            log_link = '<span class="no-log">-</span>'

        # Format command_args for expandable detail
        if command_args:
            args_display = _format_command_args(command_args)
        else:
            args_display = '<em>no args</em>'

        # Format start_time for display
        try:
            dt = datetime.datetime.fromisoformat(start_time)
            start_display = dt.strftime('%Y-%m-%d %H:%M:%S')
        except (ValueError, TypeError):
            start_display = start_time

        row = (
            f'<tr id="row-{run_id}" class="run-row {status_class}" onclick="toggleDetail(this)">'
            f'<td class="mono">{run_id}</td>'
            f'<td>{command}</td>'
            f'<td><span class="badge {status_class}">{status_label}</span></td>'
            f'<td>{start_display}</td>'
            f'<td class="mono">{duration}s</td>'
            f'<td>{log_link}</td>'
            '</tr>'
            '<tr class="detail-row" style="display:none">'
            '<td colspan="6">'
            '<div class="detail-content">'
            f'<div class="detail-field"><strong>cwd:</strong>'
            f' <pre>{cwd}</pre></div>'
            '<div class="detail-field"><strong>args:</strong>'
            f' <pre>{args_display}</pre></div>'
            '</div>'
            '</td>'
            '</tr>'
        )
        rows.append(row)

    response = '\n'.join(rows)

    return response


def _read_trace_log(trace_path: pathlib.Path) -> list[dict[str, Any]]:
    """
    Read the trace log file and return a list of trace entries.

    :param trace_path: Path to the trace.log file.
    :return: List of trace entry dictionaries.
    """

    entries: list[dict[str, Any]] = []

    if not trace_path.is_file():
        return entries

    with open(trace_path, 'r', encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    return entries


def _extract_initial_command(entry: dict[str, Any]) -> str:
    """
    Extract initial_command_received from a trace entry's command_args.

    :param entry: A single trace entry dictionary.
    :return: The initial command string, or the script filename as
        fallback.
    """

    command_args = entry.get('command_args', [])
    if command_args:
        raw = ' '.join(command_args)
        match = re.search(r"initial_command_received='([^']*)'", raw)
        if match:
            return match.group(1)

    response = pathlib.Path(entry.get('command', '')).name

    return response


def _format_command_args(args: list[str]) -> str:
    """
    Format command arguments for display in the detail row.

    :param args: List of command argument strings.
    :return: Formatted string.
    """

    if not args:
        return ''

    # The args list is typically a single large string of bash assignments.
    raw = ' '.join(args)

    return raw


def _format_duration(seconds: float) -> str:
    """
    Format a duration as seconds or minutes depending on magnitude.

    :param seconds: Duration in seconds.
    :return: Formatted string with unit.
    """

    if seconds >= 60:
        return f"{round(seconds / 60, 1)} min"

    return f"{round(seconds, 3)} s"


# =====================================================================
# HTML TEMPLATE
# =====================================================================
_HTML_TEMPLATE = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Icarus Builder Report</title>
<style>
  :root {
    --bg: #0d1117;
    --bg-card: #161b22;
    --bg-hover: #1c2129;
    --border: #30363d;
    --text: #c9d1d9;
    --text-muted: #8b949e;
    --green: #3fb950;
    --red: #f85149;
    --yellow: #d29922;
    --blue: #58a6ff;
    --mono: 'SF Mono', 'Cascadia Code', 'Fira Code', Consolas, monospace;
    --sans: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial,
            sans-serif;
  }

  * { margin: 0; padding: 0; box-sizing: border-box; }

  body {
    font-family: var(--sans);
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
    padding: 2rem;
  }

  h1 {
    font-size: 1.5rem;
    margin-bottom: 0.25rem;
  }

  .subtitle {
    color: var(--text-muted);
    font-size: 0.85rem;
    margin-bottom: 2rem;
  }

  /* Stats cards */
  .stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: 1rem;
    margin-bottom: 2rem;
  }

  .stat-card {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 1rem;
    text-align: center;
  }

  .stat-card .value {
    font-size: 1.8rem;
    font-weight: 700;
    font-family: var(--mono);
  }

  .stat-card .label {
    font-size: 0.75rem;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .stat-card .value.green  { color: var(--green); }
  .stat-card .value.red    { color: var(--red); }
  .stat-card .value.yellow { color: var(--yellow); }
  .stat-card .value.blue   { color: var(--blue); }
  .stat-card.clickable { cursor: pointer; transition: border-color 0.15s; }
  .stat-card.clickable:hover { border-color: var(--blue); }

  /* Duration chart */
  .section-title {
    font-size: 1rem;
    font-weight: 600;
    margin-bottom: 0.75rem;
    color: var(--text);
  }

  .chart-container {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 1rem;
    margin-bottom: 2rem;
  }

  .chart-bars {
    height: 120px;
    display: flex;
    align-items: flex-end;
    gap: 2px;
    overflow-x: auto;
  }

  .chart-labels {
    display: flex;
    justify-content: space-between;
    margin-bottom: 0.4rem;
    font-size: 0.7rem;
    color: var(--text-muted);
    font-family: var(--mono);
  }

  .bar {
    flex: 1;
    min-width: 6px;
    max-width: 20px;
    border-radius: 2px 2px 0 0;
    transition: opacity 0.15s;
    cursor: pointer;
  }

  .bar:hover { opacity: 0.75; }
  .bar-pass { background: var(--green); }
  .bar-fail { background: var(--red); }
  .bar-warn { background: var(--yellow); }

  /* Run table */
  .table-wrapper {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 6px;
    overflow-x: auto;
    margin-bottom: 2rem;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
    table-layout: fixed;
  }

  thead th {
    text-align: left;
    padding: 0.6rem 0.75rem;
    border-bottom: 1px solid var(--border);
    color: var(--text-muted);
    font-weight: 600;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    position: sticky;
    top: 0;
    background: var(--bg-card);
  }

  th:nth-child(1) { width: 10%; }
  th:nth-child(2) { width: 55%; }
  th:nth-child(3) { width: 5%; }
  th:nth-child(4) { width: 10%; }
  th:nth-child(5) { width: 10%; }
  th:nth-child(6) { width: 10%; }

  .run-row td {
    padding: 0.5rem 0.75rem;
    border-bottom: 1px solid var(--border);
    cursor: pointer;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .run-row:hover td { background: var(--bg-hover); }
  .run-row.highlight td { background: rgba(88,166,255,0.15); transition: background 1.5s; }

  .detail-row td {
    padding: 0;
    border-bottom: 1px solid var(--border);
  }

  .detail-content {
    padding: 0.75rem 1rem;
    background: #0d1117;
    font-size: 0.8rem;
  }

  .detail-field { margin-bottom: 0.4rem; }
  .detail-field pre {
    display: inline;
    white-space: pre-wrap;
    word-break: break-all;
    font-family: var(--mono);
    font-size: 0.75rem;
    color: var(--text-muted);
  }

  .mono { font-family: var(--mono); font-size: 0.8rem; }

  .badge {
    display: inline-block;
    padding: 0.15rem 0.5rem;
    border-radius: 4px;
    font-size: 0.7rem;
    font-weight: 700;
    font-family: var(--mono);
    letter-spacing: 0.04em;
  }

  .badge.passed  { background: rgba(63,185,80,0.15); color: var(--green); }
  .badge.failed  { background: rgba(248,81,73,0.15); color: var(--red); }
  .badge.warned  { background: rgba(210,153,34,0.15); color: var(--yellow); }

  .log-link {
    color: var(--blue);
    text-decoration: none;
    font-size: 0.8rem;
  }

  .log-link:hover { text-decoration: underline; }

  .no-log { color: var(--text-muted); font-size: 0.8rem; }

  .empty { color: var(--text-muted); font-style: italic; }

  .footer {
    color: var(--text-muted);
    font-size: 0.7rem;
    text-align: center;
    margin-top: 2rem;
  }
</style>
</head>
<body>

<h1>Icarus Builder Report</h1>
<div class="subtitle">Generated $report_generated</div>

<div class="stats">
  <div class="stat-card">
    <div class="value blue">$total_runs</div>
    <div class="label">Total Runs</div>
  </div>
  <div class="stat-card">
    <div class="value green">$passed_runs</div>
    <div class="label">Passed</div>
  </div>
  <div class="stat-card">
    <div class="value red">$failed_runs</div>
    <div class="label">Failed</div>
  </div>
  <div class="stat-card">
    <div class="value yellow">$warned_runs</div>
    <div class="label">Warned</div>
  </div>
  <div class="stat-card">
    <div class="value green">$success_rate%</div>
    <div class="label">Success Rate</div>
  </div>
  <div class="stat-card">
    <div class="value blue">$avg_duration</div>
    <div class="label">Avg Duration</div>
  </div>
  <div class="stat-card clickable" onclick="scrollToRun('$min_duration_run_id')">
    <div class="value blue">$min_duration</div>
    <div class="label">Min Duration</div>
  </div>
  <div class="stat-card clickable" onclick="scrollToRun('$max_duration_run_id')">
    <div class="value blue">$max_duration</div>
    <div class="label">Max Duration</div>
  </div>
</div>

<div class="section-title">Duration (last 100 runs)</div>
<div class="chart-container">
  $duration_bars
</div>

<div class="section-title">Run History</div>
<div class="table-wrapper">
  <table>
    <thead>
      <tr>
        <th>Run ID</th>
        <th>Command</th>
        <th>Status</th>
        <th>Started</th>
        <th>Duration</th>
        <th>Log</th>
      </tr>
    </thead>
    <tbody>
      $table_rows
    </tbody>
  </table>
</div>

<div class="footer">
  Icarus Builder &mdash; report auto-generated from trace.log
</div>

<script>
function toggleDetail(row) {
  var detail = row.nextElementSibling;
  if (detail && detail.classList.contains('detail-row')) {
    detail.style.display = detail.style.display === 'none' ? '' : 'none';
  }
}

function scrollToRun(runId) {
  var row = document.getElementById('row-' + runId);
  if (!row) return;

  // Briefly highlight
  row.classList.add('highlight');
  setTimeout(function() { row.classList.remove('highlight'); }, 1500);

  // Expand detail
  var detail = row.nextElementSibling;
  if (detail && detail.classList.contains('detail-row')) {
    detail.style.display = '';
  }

  // Scroll into view
  row.scrollIntoView({ behavior: 'smooth', block: 'center' });
}
</script>

</body>
</html>
"""
