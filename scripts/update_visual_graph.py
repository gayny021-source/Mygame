#!/usr/bin/env python3
"""Rebuild the graphify AST graph and graph.html before a commit (no LLM, no API).

Run from the repo root: python3 scripts/update_visual_graph.py
Exit code is always 0 so a commit is never blocked; a skipped or failed rebuild
is reported on stderr, so it is visible when the output is not discarded.
"""
import os
import shutil
import subprocess
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.environ["PATH"] = os.path.expanduser("~/.local/bin") + os.pathsep + os.environ.get("PATH", "")
exe = shutil.which("graphify")
if not exe:
    print("update_visual_graph: SKIPPED — graphify CLI not found", file=sys.stderr)
    sys.exit(0)
try:
    r = subprocess.run([exe, "update", "."], cwd=root, capture_output=True, text=True, timeout=300)
except subprocess.TimeoutExpired:
    print("update_visual_graph: SKIPPED — graphify update timed out", file=sys.stderr)
    sys.exit(0)
if r.returncode != 0:
    print(f"update_visual_graph: FAILED (rc={r.returncode}) — {r.stderr.strip()[-300:]}", file=sys.stderr)
sys.exit(0)
