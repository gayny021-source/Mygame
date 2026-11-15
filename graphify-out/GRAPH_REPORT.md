# Graph Report - Mygame  (2026-11-15)

## Corpus Check
- 81 files · ~1,106,059 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 589 file(s) not represented in the graph (top: .gd 270, .uid 264, .tscn 18)
- WARNING: 589 of 1296 files seen (45%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 328 nodes · 455 edges · 120 communities (11 shown, 109 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d4e94ba5`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- vis-network.min.js
- entities
- nb
- g
- Kv
- d
- yd
- update_visual_graph.py
- constants
- zM
- rb

## God Nodes (most connected - your core abstractions)
1. `nb()` - 32 edges
2. `Ib()` - 31 edges
3. `g()` - 19 edges
4. `d()` - 18 edges
5. `yd()` - 15 edges
6. `entities` - 14 edges
7. `t()` - 13 edges
8. `A()` - 12 edges
9. `formulas` - 11 edges
10. `constants` - 10 edges

## Surprising Connections (you probably didn't know these)
- `kd()` --indirect_call--> `A()`  [INFERRED]
  scripts/vendor/vis-network.min.js → scripts/vendor/vis-network.min.js  _Bridges community 3 → community 6_
- `nv()` --indirect_call--> `A()`  [INFERRED]
  scripts/vendor/vis-network.min.js → scripts/vendor/vis-network.min.js  _Bridges community 3 → community 4_
- `sN()` --indirect_call--> `A()`  [INFERRED]
  scripts/vendor/vis-network.min.js → scripts/vendor/vis-network.min.js  _Bridges community 3 → community 2_
- `g()` --indirect_call--> `d()`  [INFERRED]
  scripts/vendor/vis-network.min.js → scripts/vendor/vis-network.min.js  _Bridges community 3 → community 5_
- `g()` --indirect_call--> `Pp()`  [INFERRED]
  scripts/vendor/vis-network.min.js → scripts/vendor/vis-network.min.js  _Bridges community 3 → community 0_

## Import Cycles
- None detected.

## Communities (120 total, 109 thin omitted)

### Community 0 - "vis-network.min.js"
Cohesion: 0.05
Nodes (32): Av(), Ay(), Cb(), cM(), Cv(), Dp(), eb(), Ep() (+24 more)

### Community 1 - "entities"
Cohesion: 0.07
Nodes (28): entities, added, charisma, display_name, faith, mind, name, own_stat (+20 more)

### Community 2 - "nb"
Cohesion: 0.13
Nodes (29): AN(), bN(), dD(), dN(), DR(), EN(), fN(), Ib() (+21 more)

### Community 3 - "g"
Cohesion: 0.13
Nodes (23): A(), Af(), AP(), bp(), cn(), Z(), e(), I() (+15 more)

### Community 4 - "Kv"
Cohesion: 0.27
Nodes (15): Cy(), gy(), Hv(), jv(), Kv(), nv(), ov(), Qv() (+7 more)

### Community 5 - "d"
Cohesion: 0.21
Nodes (11): d(), A(), b(), F(), G(), j(), k(), S() (+3 more)

### Community 6 - "yd"
Cohesion: 0.21
Nodes (13): bd(), Bf(), dv(), _f(), Hf(), kd(), Pf(), Qf() (+5 more)

### Community 7 - "update_visual_graph.py"
Cohesion: 0.29
Nodes (5): build_edges(), classify(), collect(), main(), mention_keys()

### Community 8 - "constants"
Cohesion: 0.20
Nodes (10): constants, added, name, notes, referenced_by, revised, source, status (+2 more)

### Community 9 - "zM"
Cohesion: 0.28
Nodes (9): BM(), ch(), dh(), Ff(), hh(), lh(), PM(), pv() (+1 more)

### Community 10 - "rb"
Cohesion: 0.33
Nodes (6): aD(), gN(), kR(), rb(), sD(), wR()

## Knowledge Gaps
- **109 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `d()` connect `d` to `vis-network.min.js`, `zM`, `g`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `g()` (e.g. with `e()` and `I()`) actually correct?**
  _`g()` has 7 INFERRED edges - model-reasoned connections that need verification._
- **Should `vis-network.min.js` be split into smaller, more focused modules?**
  _Cohesion score 0.050816696914700546 - nodes in this community are weakly interconnected._
- **Are the 5 inferred relationships involving `d()` (e.g. with `L()` and `P()`) actually correct?**
  _`d()` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Should `entities` be split into smaller, more focused modules?**
  _Cohesion score 0.06896551724137931 - nodes in this community are weakly interconnected._
- **Should `nb` be split into smaller, more focused modules?**
  _Cohesion score 0.13054187192118227 - nodes in this community are weakly interconnected._
- **Should `g` be split into smaller, more focused modules?**
  _Cohesion score 0.13438735177865613 - nodes in this community are weakly interconnected._