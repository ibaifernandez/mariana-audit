#!/usr/bin/env python3
"""Incremental semantic+AST update for graphify + republish to global graph.

Designed to run as a post-commit companion to graphify's built-in code-only
rebuild hook. Detects changed docs/papers/images since last manifest and
re-extracts only those via `claude-cli` backend (uses Claude Code subscription).

Usage:
    python3 scripts/graphify-doc-sync.py            # auto-detect changes via manifest
    python3 scripts/graphify-doc-sync.py --force <file1> <file2>  # force specific files

Env:
    GRAPHIFY_DOC_SYNC_SKIP=1     skip entirely (e.g. emergency)
    GRAPHIFY_DOC_SYNC_NO_GLOBAL=1   skip republish to global
    GRAPHIFY_DOC_SYNC_TAG=<tag>     repo tag for global graph (default: parent dirname)

Idempotent: if no doc/image changes detected, exits 0 without touching anything.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GRAPHIFY_OUT = REPO_ROOT / "graphify-out"
GRAPH_JSON = GRAPHIFY_OUT / "graph.json"


def log(msg: str) -> None:
    print(f"[doc-sync] {msg}", flush=True)


def python_interp() -> str:
    pinned = GRAPHIFY_OUT / ".graphify_python"
    if pinned.exists():
        path = pinned.read_text(encoding="utf-8").strip()
        if path and Path(path).exists():
            return path
    return sys.executable


def detect_changes() -> tuple[list[Path], list[Path], list[str]]:
    """Return (code_changed, semantic_changed, deleted) since last manifest."""
    code_exts = {".py", ".ts", ".js", ".mjs", ".go", ".rs", ".java", ".cpp", ".c", ".rb", ".swift", ".kt"}
    semantic_exts = {".md", ".txt", ".pdf", ".docx", ".html", ".png", ".jpg", ".jpeg", ".webp", ".svg"}

    interp = python_interp()
    cmd = [
        interp,
        "-c",
        "import json; from graphify.detect import detect_incremental; from pathlib import Path; "
        "r = detect_incremental(Path('.')); print(json.dumps(r))",
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, cwd=REPO_ROOT)
    except subprocess.CalledProcessError as e:
        log(f"detect_incremental failed: {e.stderr.strip()[:200]}")
        return [], [], []

    data = json.loads(result.stdout)
    new_files = data.get("new_files", {})
    deleted = list(data.get("deleted_files", []))

    code, semantic = [], []
    for kind, files in new_files.items():
        for f in files:
            p = Path(f)
            if p.suffix in code_exts:
                code.append(p)
            elif p.suffix in semantic_exts:
                semantic.append(p)
    return code, semantic, deleted


def run_extraction(code_files: list[Path], semantic_files: list[Path], deleted: list[str]) -> bool:
    """Run AST + semantic via claude-cli, merge into existing graph, force-write."""
    interp = python_interp()
    script = '''
import json, time
from pathlib import Path
from graphify.extract import collect_files, extract as ast_extract
from graphify.llm import extract_corpus_parallel
from graphify.build import build_merge, build_from_json
from graphify.cluster import cluster as cluster_fn, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate
from graphify.export import to_json
from graphify.detect import save_manifest, detect_incremental

CODE = [Path(p) for p in PLACEHOLDER_CODE]
SEM  = [Path(p) for p in PLACEHOLDER_SEM]
DEL  = PLACEHOLDER_DEL

ast_result = {"nodes": [], "edges": [], "input_tokens": 0, "output_tokens": 0}
if CODE:
    ast_files = []
    for f in CODE:
        ast_files.extend(collect_files(f) if f.is_dir() else [f])
    if ast_files:
        ast_result = ast_extract(ast_files, cache_root=Path("."))
        print(f"[doc-sync] AST: {len(ast_result['nodes'])} nodes from {len(ast_files)} code files", flush=True)

sem_result = {"nodes": [], "edges": [], "hyperedges": [], "input_tokens": 0, "output_tokens": 0}
sem_files = SEM + CODE  # include code for cross-file edges
if sem_files:
    done = {"n": 0, "t0": time.time()}
    def progress(idx, total, chunk_result):
        done["n"] += 1
        elapsed = time.time() - done["t0"]
        nodes = len(chunk_result.get("nodes", [])) if chunk_result else 0
        edges = len(chunk_result.get("edges", [])) if chunk_result else 0
        print(f"[doc-sync] chunk {done['n']}/{total} ({nodes}n/{edges}e) {elapsed:.0f}s", flush=True)
    sem_result = extract_corpus_parallel(
        files=sem_files, backend="claude-cli", root=Path("."),
        chunk_size=20, token_budget=60_000, max_concurrency=4,
        on_chunk_done=progress,
    )
    print(f"[doc-sync] semantic: {len(sem_result['nodes'])} nodes, {sem_result.get('input_tokens',0):,} in / {sem_result.get('output_tokens',0):,} out tokens", flush=True)

seen = {n["id"] for n in ast_result["nodes"]}
merged_nodes = list(ast_result["nodes"])
for n in sem_result["nodes"]:
    if n["id"] not in seen:
        merged_nodes.append(n)
        seen.add(n["id"])
new_extract = {
    "nodes": merged_nodes,
    "edges": ast_result["edges"] + sem_result["edges"],
    "hyperedges": sem_result.get("hyperedges", []),
    "input_tokens": sem_result.get("input_tokens", 0),
    "output_tokens": sem_result.get("output_tokens", 0),
}

G = build_merge([new_extract], graph_path="graphify-out/graph.json", prune_sources=DEL or None)
print(f"[doc-sync] merged graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges", flush=True)

merged_out = {
    "nodes": [{"id": n, **d} for n, d in G.nodes(data=True)],
    "edges": [{**{k: v for k, v in d.items() if k not in ("_src", "_tgt", "source", "target")},
               "source": d.get("_src", u), "target": d.get("_tgt", v)} for u, v, d in G.edges(data=True)],
    "hyperedges": list(G.graph.get("hyperedges", [])),
    "input_tokens": sem_result.get("input_tokens", 0),
    "output_tokens": sem_result.get("output_tokens", 0),
}

G2 = build_from_json(merged_out)
communities = cluster_fn(G2)
cohesion = score_all(G2, communities)
gods = god_nodes(G2)
surprises = surprising_connections(G2, communities)
placeholder_labels = {cid: f"Community {cid}" for cid in communities}
questions = suggest_questions(G2, communities, placeholder_labels)

existing_labels_path = Path("graphify-out/.graphify_labels.json")
if existing_labels_path.exists():
    old_labels = json.loads(existing_labels_path.read_text(encoding="utf-8"))
    labels = {int(k): v for k, v in old_labels.items() if int(k) in communities}
    for cid in communities:
        if cid not in labels:
            labels[cid] = placeholder_labels[cid]
else:
    labels = placeholder_labels

incremental = detect_incremental(Path("."))
detection_full = {
    "files": incremental.get("files", {}),
    "all_files": incremental.get("files", {}),
    "total_files": incremental.get("total_files", 0),
    "total_words": incremental.get("total_words", 0),
    "skipped_sensitive": incremental.get("skipped_sensitive", []),
}
tokens = {"input": merged_out["input_tokens"], "output": merged_out["output_tokens"]}
report = generate(G2, communities, cohesion, labels, gods, surprises, detection_full, tokens, ".", suggested_questions=questions)
Path("graphify-out/GRAPH_REPORT.md").write_text(report, encoding="utf-8")
wrote = to_json(G2, communities, "graphify-out/graph.json", force=True)
save_manifest(incremental.get("files", {}))
print(f"[doc-sync] DONE — wrote graph.json: {wrote}, final: {G2.number_of_nodes()} nodes, {G2.number_of_edges()} edges", flush=True)
'''
    code_repr = json.dumps([str(p) for p in code_files])
    sem_repr = json.dumps([str(p) for p in semantic_files])
    del_repr = json.dumps(deleted)
    script = script.replace("PLACEHOLDER_CODE", code_repr).replace("PLACEHOLDER_SEM", sem_repr).replace("PLACEHOLDER_DEL", del_repr)

    result = subprocess.run([interp, "-c", script], cwd=REPO_ROOT)
    return result.returncode == 0


def republish_global(tag: str) -> bool:
    try:
        result = subprocess.run(
            ["graphify", "global", "add", str(GRAPH_JSON), "--as", tag],
            capture_output=True, text=True, cwd=REPO_ROOT,
        )
        if result.returncode == 0:
            log(f"global: {result.stdout.strip()}")
            return True
        log(f"global add failed: {result.stderr.strip()[:200]}")
        return False
    except FileNotFoundError:
        log("graphify CLI not on PATH — skip global republish")
        return False


def main() -> int:
    if os.environ.get("GRAPHIFY_DOC_SYNC_SKIP") == "1":
        log("skipped (GRAPHIFY_DOC_SYNC_SKIP=1)")
        return 0

    parser = argparse.ArgumentParser()
    parser.add_argument("--force", nargs="*", help="force-sync specific files (paths relative to repo root)")
    args = parser.parse_args()

    if args.force:
        forced = [Path(p) for p in args.force]
        code = [p for p in forced if p.suffix in {".py", ".ts", ".js", ".mjs", ".go", ".rs"}]
        semantic = [p for p in forced if p.suffix in {".md", ".txt", ".pdf", ".docx", ".html", ".png", ".jpg", ".jpeg", ".webp", ".svg"}]
        deleted: list[str] = []
        log(f"force mode: {len(code)} code + {len(semantic)} semantic files")
    else:
        code, semantic, deleted = detect_changes()
        if not semantic and not deleted:
            log("no semantic changes — graphify built-in code hook covers this. skip.")
            return 0
        log(f"detected: {len(code)} code + {len(semantic)} semantic + {len(deleted)} deleted")

    if not run_extraction(code, semantic, deleted):
        log("extraction failed")
        return 1

    if os.environ.get("GRAPHIFY_DOC_SYNC_NO_GLOBAL") == "1":
        log("skip global republish (GRAPHIFY_DOC_SYNC_NO_GLOBAL=1)")
        return 0

    tag = os.environ.get("GRAPHIFY_DOC_SYNC_TAG") or REPO_ROOT.name
    republish_global(tag)
    return 0


if __name__ == "__main__":
    sys.exit(main())
