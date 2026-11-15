#!/usr/bin/env python3
"""Rebuild graphify-out/graph.html and graph.json as a full project map: pure Python, no LLM, no graphify CLI.

Run from the repo root: python3 scripts/update_visual_graph.py
Nodes: design docs, studio agents and skills, GDScript, scenes. Edges: regex mentions,
extends / preload / load / ext_resource / autoload. Prints "Nodes: X, Edges: Y".
Exit code is always 0 so a commit is never blocked; a failure is reported on stderr.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "graphify-out", "graph.html")
# vis-network 9.1.9 (MIT / Apache-2.0), inlined so the page opens offline and behind proxies.
VIS = os.path.join(ROOT, "scripts", "vendor", "vis-network.min.js")
# addons/ is third-party (gdUnit4: hundreds of scripts) and would drown the project map.
SKIP_DIRS = {".git", ".godot", ".import", "graphify-out", ".template_archive", "addons", "node_modules"}
GROUPS = {
    "GDD / Docs": "#e6b422",
    "Studio / Agents": "#a56bf5",
    "GDScript": "#4a9cf5",
    "Scenes": "#4cc26a",
}


def classify(rel: str) -> str | None:
    name = os.path.basename(rel)
    if rel.endswith(".gd"):
        return "GDScript"
    if rel.endswith(".tscn") or rel == "project.godot":
        return "Scenes"
    if rel.startswith(".claude/agents/") and rel.endswith(".md") and rel.count("/") == 2:
        return "Studio / Agents"
    if rel.startswith(".claude/skills/") and name == "SKILL.md":
        return "Studio / Agents"
    if rel.startswith("design/") and rel.endswith(".md") and name != "CLAUDE.md":
        return "GDD / Docs"
    if rel in ("CLAUDE.md", "USER_PREFERENCES.md"):
        return "GDD / Docs"
    return None


def collect() -> dict[str, dict]:
    nodes: dict[str, dict] = {}
    for base, dirs, files in os.walk(ROOT):
        rel_base = os.path.relpath(base, ROOT).replace(os.sep, "/")
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and "archive" not in d.lower()]
        for name in files:
            rel = f"{rel_base}/{name}".removeprefix("./")
            group = classify(rel)
            if not group or "archive" in rel.lower():
                continue
            try:
                text = open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            label = rel.split("/")[-2] if name == "SKILL.md" else name
            nodes[rel] = {"group": group, "label": label, "text": text}
    return nodes


def mention_keys(rel: str) -> set[str]:
    """Exact keys only: path, res:// path, file name with extension, @agent, hyphenated compound name."""
    name = os.path.basename(rel)
    stem = name.rsplit(".", 1)[0]
    keys = {rel, f"res://{rel}"}
    if name == "SKILL.md":
        skill = rel.split("/")[-2]
        keys |= {f"skills/{skill}", f"{skill}/SKILL.md"}
        if "-" in skill:
            keys.add(skill)
        return keys
    if name != "CLAUDE.md" or rel == "CLAUDE.md":
        keys.add(name)
    if rel.startswith(".claude/agents/"):
        keys.add(f"@{stem}")
    elif rel.startswith("design/") and "-" in stem:
        keys.add(stem)
    return keys


def build_edges(nodes: dict[str, dict]) -> set[tuple[str, str]]:
    key_to_node: dict[str, str] = {}
    for rel in nodes:
        if rel == "project.godot":
            continue
        for key in mention_keys(rel):
            key_to_node.setdefault(key.lower(), rel)
    ordered = sorted(key_to_node, key=len, reverse=True)
    pattern = re.compile(
        r"(?<![\w/.-])(" + "|".join(re.escape(k) for k in ordered) + r")(?![\w-])", re.IGNORECASE
    )
    class_names = {
        m.group(1): rel
        for rel, node in nodes.items() if rel.endswith(".gd")
        for m in re.finditer(r"^class_name\s+(\w+)", node["text"], re.M)
    }
    autoloads: dict[str, str] = {}
    edges: set[tuple[str, str]] = set()
    godot = nodes.get("project.godot")
    if godot:
        section = re.search(r"^\[autoload\]\n(.*?)(?=^\[|\Z)", godot["text"], re.M | re.S)
        for m in re.finditer(r'^(\w+)="\*?res://([^"]+)"', section.group(1) if section else "", re.M):
            autoloads[m.group(1)] = m.group(2)
        main = re.search(r'^run/main_scene="res://([^"]+)"', godot["text"], re.M)
        for target in [main.group(1) if main else "", *autoloads.values()]:
            if target in nodes:
                edges.add(("project.godot", target))
    for rel, node in nodes.items():
        if rel == "project.godot":
            continue
        text = node["text"]
        targets = {key_to_node[m.group(1).lower()] for m in pattern.finditer(text)}
        if node["group"] in ("GDScript", "Scenes"):
            targets |= set(re.findall(r'res://([^"\')\s]+)', text))
            for m in re.finditer(r"^extends\s+(\w+)", text, re.M):
                targets.add(class_names.get(m.group(1), ""))
            for name, path in autoloads.items():
                if re.search(rf"\b{name}\.", text):
                    targets.add(path)
        for target in targets:
            if target in nodes and target not in (rel, "project.godot"):
                edges.add((rel, target))
    return edges


HTML = """<!doctype html>
<html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Критический провал — карта проекта</title>
<script>__VIS__</script>
<style>
html,body{margin:0;height:100%;background:#14161b;color:#e8e6df;font:15px/1.4 system-ui,sans-serif}
#bar{position:fixed;top:0;left:0;right:0;z-index:2;padding:8px 10px;background:#1c1f26ee;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
#q{flex:1 1 180px;min-width:140px;padding:8px 10px;border-radius:8px;border:1px solid #3a3f4b;background:#0f1115;color:inherit;font-size:16px}
label{display:flex;align-items:center;gap:5px;padding:6px 8px;border-radius:8px;background:#0f1115;white-space:nowrap}
.dot{width:12px;height:12px;border-radius:50%;display:inline-block}
#stat{opacity:.7;font-size:13px}
#net{position:absolute;top:0;left:0;right:0;bottom:0}
#info{position:fixed;left:0;right:0;bottom:0;z-index:2;padding:8px 10px;background:#1c1f26ee;font-size:13px;max-height:30%;overflow:auto;display:none}
</style></head><body>
<div id="bar"><input id="q" placeholder="Поиск: имя файла или путь" autocomplete="off"><span id="filters"></span><span id="stat"></span></div>
<div id="net"></div><div id="info"></div>
<script>
const GROUPS=__GROUPS__,RAW_NODES=__NODES__,RAW_EDGES=__EDGES__;
const nodes=new vis.DataSet(RAW_NODES.map(n=>({id:n.id,label:n.label,group:n.group,title:n.id,value:n.deg})));
const edges=new vis.DataSet(RAW_EDGES.map((e,i)=>({id:i,from:e[0],to:e[1]})));
const groupOpts={};for(const g in GROUPS)groupOpts[g]={color:{background:GROUPS[g],border:GROUPS[g],highlight:{background:"#ffffff",border:GROUPS[g]}}};
const net=new vis.Network(document.getElementById("net"),{nodes,edges},{
 groups:groupOpts,
 nodes:{shape:"dot",scaling:{min:6,max:30},font:{color:"#e8e6df",size:13,strokeWidth:3,strokeColor:"#14161b"}},
 edges:{color:{color:"#4a4f5c",highlight:"#e8e6df",opacity:.5},arrows:{to:{enabled:true,scaleFactor:.4}},smooth:false},
 physics:{solver:"forceAtlas2Based",forceAtlas2Based:{gravitationalConstant:-60,springLength:90},stabilization:{iterations:200}},
 interaction:{hover:true,tooltipDelay:120}});
net.once("stabilizationIterationsDone",()=>net.setOptions({physics:false}));
const active=new Set(Object.keys(GROUPS)),filters=document.getElementById("filters"),q=document.getElementById("q");
for(const g in GROUPS){const l=document.createElement("label");l.innerHTML=`<input type="checkbox" checked><span class="dot" style="background:${GROUPS[g]}"></span>${g}`;
 l.firstChild.onchange=e=>{e.target.checked?active.add(g):active.delete(g);apply()};filters.appendChild(l)}
function apply(){const s=q.value.trim().toLowerCase();let shown=0;
 nodes.update(RAW_NODES.map(n=>{const ok=active.has(n.group)&&(!s||n.id.toLowerCase().includes(s));if(ok)shown++;return{id:n.id,hidden:!ok}}));
 document.getElementById("stat").textContent=`Узлов: ${shown} из ${RAW_NODES.length}, связей: ${RAW_EDGES.length}`}
q.oninput=apply;apply();
const info=document.getElementById("info");
net.on("click",p=>{if(!p.nodes.length){info.style.display="none";return}
 const id=p.nodes[0],out=RAW_EDGES.filter(e=>e[0]===id).map(e=>e[1]),inc=RAW_EDGES.filter(e=>e[1]===id).map(e=>e[0]);
 info.style.display="block";info.innerHTML=`<b>${id}</b><br>ссылается на (${out.length}): ${out.join(", ")||"—"}<br>на него ссылаются (${inc.length}): ${inc.join(", ")||"—"}`});
</script></body></html>
"""


def main() -> None:
    nodes = collect()
    edges = build_edges(nodes)
    degree = dict.fromkeys(nodes, 0)
    for src, dst in edges:
        degree[src] += 1
        degree[dst] += 1
    node_list = [
        {"id": rel, "label": n["label"], "group": n["group"], "deg": degree[rel]}
        for rel, n in sorted(nodes.items())
    ]
    vis = open(VIS, encoding="utf-8").read().replace("</script", "<\\/script")
    html = (
        HTML.replace("__GROUPS__", json.dumps(GROUPS, ensure_ascii=False))
        .replace("__NODES__", json.dumps(node_list, ensure_ascii=False))
        .replace("__EDGES__", json.dumps(sorted(edges), ensure_ascii=False))
        .replace("__VIS__", vis)
    )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    graph = {
        "nodes": [{"id": n["id"], "label": n["label"], "group": n["group"]} for n in node_list],
        "links": [{"source": src, "target": dst} for src, dst in sorted(edges)],
    }
    with open(os.path.join(os.path.dirname(OUT), "graph.json"), "w", encoding="utf-8") as f:
        json.dump(graph, f, ensure_ascii=False, indent=1)
    print(f"Nodes: {len(nodes)}, Edges: {len(edges)}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # never block a commit
        print(f"update_visual_graph: FAILED — {exc}", file=sys.stderr)
    sys.exit(0)
