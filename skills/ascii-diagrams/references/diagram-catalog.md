# ASCII Diagram Catalog

A reference of diagram types renderable in plain text, grouped by purpose.

---

## 1. Boxes & Containers

### Basic ASCII

```
+--------+
|  Box   |
+--------+
```

### Single-line box-drawing

```
┌────────┐
│  Box   │
└────────┘
```

### Rounded

```
╭────────╮
│ Box    │
╰────────╯
```

### Double-line

```
╔════════╗
║  Box   ║
╚════════╝
```

### Dashed

```
┌─ ─ ─ ─ ┐
  dashed
└─ ─ ─ ─ ┘
```

### 3D / Isometric

```
    +--------+
   /|       /|
  +--------+ |
  | |      | |
  | +------|-+
  |/       |/
  +--------+
```

### Shadowed

```
┌────────┐
│  Box   │▒
└────────┘▒
 ▒▒▒▒▒▒▒▒▒▒
```

### Nested

```
┌─────────────────────┐
│ Outer               │
│  ┌───────────────┐  │
│  │ Inner         │  │
│  │  ┌─────────┐  │  │
│  │  │ Core    │  │  │
│  │  └─────────┘  │  │
│  └───────────────┘  │
└─────────────────────┘
```

### Titled / Banner

```
┌─ Config ──────────┐
│ host: localhost   │
│ port: 8080        │
└───────────────────┘
```

### Callout / Speech bubble

```
  ┌─────────────────┐
  │ Hey, listen!    │
  └──────┬──────────┘
         ▼
       (you)
```

---

## 2. Hierarchy & Trees

### Filesystem tree

```
project/
├── src/
│   ├── main.ts
│   ├── utils.ts
│   └── components/
│       ├── Header.tsx
│       └── Footer.tsx
├── tests/
│   └── main.test.ts
├── package.json
└── README.md
```

### Org chart

```
          ┌───────┐
          │  CEO  │
          └───┬───┘
      ┌───────┼────────┐
   ┌──┴──┐ ┌──┴──┐ ┌───┴───┐
   │ CTO │ │ CFO │ │  COO  │
   └──┬──┘ └─────┘ └───────┘
   ┌──┴──┬──────┐
  Eng   QA   DevOps
```

### Radial mindmap

```
          Build
            │
  Design ─[Core]─ Test
            │
          Ship
```

### DOM / AST tree

```
Program
├── FunctionDecl "main"
│   ├── Params []
│   └── Body
│       ├── VarDecl "x"
│       └── ReturnStmt
│           └── BinaryOp "+"
│               ├── Literal 1
│               └── Literal 2
```

### Decision tree

```
        Is it raining?
         /         \
       yes          no
       /              \
  Umbrella?       Too hot?
   /   \           /   \
  yes   no       yes    no
   │    │         │      │
  Go   Stay      Stay   Go
```

### Binary tree

```
        8
       / \
      3   10
     / \    \
    1   6   14
       / \  /
      4  7 13
```

### Bracket / Tournament

```
A ──┐
    ├── A ──┐
B ──┘       │
            ├── A
C ──┐       │
    ├── D ──┘
D ──┘
```

---

## 3. Flow & Process

### Linear flow

```
[Start] → [Process] → [Validate] → [End]
```

### Branching flow

```
        [Input]
           │
        <valid?>
         ╱   ╲
      yes     no
       │       │
    [Process] [Error]
       │       │
       └───┬───┘
           ▼
         [End]
```

### Pipeline

```
source ══▶ filter ══▶ transform ══▶ sink
```

### Loop / Cycle

```
      ┌──────────────┐
      ▼              │
   [Fetch]           │
      │              │
      ▼              │
   [Process] ────────┤
      │              │
      ▼              │
   [Check] ──yes─────┘
      │
      no
      ▼
    [Done]
```

### DAG / Dependency graph

```
  [A] ──▶ [B] ──▶ [D]
   │       │       ▲
   ▼       ▼       │
  [C] ──▶ [E] ─────┘
```

### Call graph

```
main ──▶ init ──▶ config
  │       │
  │       └─▶ logger
  │
  └─▶ run ──▶ handle ──▶ db
              │
              └─▶ cache
```

### Fishbone / Ishikawa

```
  People \         \ Process
          \         \
           \─────────\──────────▶ [Problem]
           /         /
          /         /
Machines /         / Materials
```

---

## 4. State, Sequence, Interaction

### State machine

```
 ┌──────┐  start   ┌─────────┐
 │ Idle │─────────▶│ Running │
 └──────┘          └────┬────┘
     ▲                  │ done
     │                  ▼
     │               ┌──────┐
     └─── reset ─────│ Done │
                     └──────┘
```

### Sequence diagram

```
Client       Server        DB
  │            │            │
  │── req ───▶│            │
  │            │── qry ───▶│
  │            │◀── data ──│
  │◀── res ───│            │
  │            │            │
```

### Petri net

```
 (P1) ──▶ [T1] ──▶ (P2) ──▶ [T2] ──▶ (P3)
                     │                  ▲
                     └──▶ [T3] ─────────┘
```

### Swimlane

```
┌──────────┬────────────┬──────────┐
│  User    │  System    │  DB      │
├──────────┼────────────┼──────────┤
│ [login]──┼──▶[auth]───┼──▶[qry]  │
│          │     │      │    │    │
│ [view]◀──┼─────┴◀─────┼────┘    │
└──────────┴────────────┴──────────┘
```

### UML activity

```
    ●
    │
    ▼
 [Login]
    │
   ◇ valid?
   ╱ ╲
 yes   no
  │    │
  ▼    ▼
[Home] [Retry]
  │      │
  ▼      │
  ●◀─────┘
```

---

## 5. Data Visualization

### Bar chart

```
A │████████████ 24
B │██████       12
C │██████████   20
D │████          8
  └─────────────────
```

### Sparkline

```
Revenue: ▁▂▄▇▆▅▂▃▁▄█▇
```

### Heatmap

```
        M  T  W  T  F
Alice   ░  ▒  ▓  █  ▒
Bob     ▒  ▓  ░  ▒  ▓
Carol   █  ▒  ▒  ░  ▓
```

### Scatter

```
10│         *
 8│     *       *
 6│  *      *
 4│    *  *
 2│*        *
 0└──────────────
  0  2  4  6  8  10
```

### Box plot

```
    min  Q1  median  Q3  max
     ├───[═══|═══]───┤
```

### Histogram

```
 0-10  │████
10-20  │█████████
20-30  │██████████████
30-40  │████████
40-50  │███
```

### Line plot

```
10│    ╱╲
 8│   ╱  ╲    ╱╲
 6│  ╱    ╲  ╱  ╲
 4│ ╱      ╲╱
 2│╱
  └────────────────
```

### Stacked bar

```
Q1 │████▓▓▓░░░    A=4 B=3 C=3
Q2 │██████▓▓░░    A=6 B=2 C=2
Q3 │███▓▓▓▓▓░░    A=3 B=5 C=2
```

### Quadrant / 2×2

```
         high impact
              │
     Do now   │   Plan
              │
  ────────────┼────────────
              │
     Drop     │  Delegate
              │
         low impact
 low effort ──┴── high effort
```

### Funnel

```
 ████████████████  Visitors  10,000
  ██████████       Signups    4,000
    ██████         Trials     2,000
      ██           Paid         500
```

### Radar / Spider (approx)

```
         Speed
          *
         ╱ ╲
        ╱   ╲
  Power*─────* Range
        ╲   ╱
         ╲ ╱
          *
        Armor
```

### Sankey-ish

```
Revenue ═══════╗
               ╠══▶ Salaries ════════▶
Investment ════╣
               ╠══▶ Ops ═════▶
Other ═════════╝
```

### Pie-as-bar

```
████████████ 40%  Engineering
████████     25%  Sales
██████       20%  Marketing
████         15%  Other
```

---

## 6. Technical / System

### Bit field (IPv4 header-like)

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version|  IHL  |     ToS     |          Total Length           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### Memory layout

```
High ┌──────────┐
     │  Stack   │ ↓ grows down
     │    ...   │
     │          │
     │    ...   │
     │   Heap   │ ↑ grows up
     ├──────────┤
     │  .bss    │
     │  .data   │
     │  .text   │
Low  └──────────┘
```

### ER diagram

```
┌─────────┐ 1        ∞ ┌─────────┐
│  User   │────────────│ Order   │
├─────────┤            ├─────────┤
│ id  PK  │            │ id  PK  │
│ name    │            │ user_id │
│ email   │            │ total   │
└─────────┘            └─────────┘
```

### UML class

```
┌────────────────────┐
│ User               │
├────────────────────┤
│ - id: int          │
│ - name: string     │
│ - email: string    │
├────────────────────┤
│ + login(): bool    │
│ + logout(): void   │
└────────────────────┘
```

### C4 / architecture

```
        ┌────────────┐
        │  Browser   │
        └─────┬──────┘
              │ HTTPS
        ┌─────▼──────┐
        │  Gateway   │
        └─┬────────┬─┘
          ▼        ▼
     ┌────────┐ ┌──────┐
     │ Auth   │ │ API  │──▶ ┌────┐
     └────────┘ └──────┘    │ DB │
                            └────┘
```

### Git graph

```
* G (main)
* F
|\
| * E (feature)
| * D
|/
* C
* B
* A
```

### Network topology

```
     [Internet]
         │
     ┌───┴───┐
     │ Router│
     └───┬───┘
    ┌────┼────┐
    ▼    ▼    ▼
 [PC1][PC2][Srv]
```

### Logic gates

```
     A ──┐
         ├─AND─┐
     B ──┘     ├─OR──▶ Out
     C ───NOT──┘
```

### Register layout

```
    31                16 15                 0
   ┌────────────────────┬────────────────────┐
   │       High         │        Low         │
   └────────────────────┴────────────────────┘
    EAX ───────────────────────────────────▶
                         AX ────────────────▶
                         AH ─────▶ AL ──────▶
```

### State-transition table

```
 State\Input │  A   │  B   │  C
 ────────────┼──────┼──────┼──────
    S0       │ S1   │ S0   │ S2
    S1       │ S1   │ S2   │ S0
    S2       │ S0   │ S2   │ S1
```

---

## 7. UI / Layout

### Wireframe

```
┌────────────────────────────────┐
│ ☰  Logo              Profile ▾ │
├────────────────────────────────┤
│ ┌──────┐ ┌──────────────────┐  │
│ │ Nav  │ │    Content       │  │
│ │      │ │                  │  │
│ │ • A  │ │                  │  │
│ │ • B  │ │                  │  │
│ └──────┘ └──────────────────┘  │
└────────────────────────────────┘
```

### Form mockup

```
Name:   [_________________________]
Email:  [_________________________]
Role:   [Engineer               ▼ ]
        [✓] Subscribe to newsletter
        [ ] Agree to terms

              [ Cancel ] [ Submit ]
```

### Table

```
┌──────────┬────────┬──────────┐
│ Name     │ Age    │ Role     │
├──────────┼────────┼──────────┤
│ Alice    │ 32     │ Engineer │
│ Bob      │ 28     │ Designer │
│ Carol    │ 41     │ PM       │
└──────────┴────────┴──────────┘
```

### Kanban board

```
┌──────────┬──────────┬──────────┐
│   TODO   │   WIP    │  DONE    │
├──────────┼──────────┼──────────┤
│ ▫ Task A │ ▫ Task C │ ✓ Task E │
│ ▫ Task B │          │ ✓ Task F │
│          │          │ ✓ Task G │
└──────────┴──────────┴──────────┘
```

### Tabs

```
╭──────╮╭──────╮╭──────╮
│ Home ││ Docs ││ API  │
╰──────╯└──┬───┘└──────┘
   ────────┴────────────
   Active tab content here
```

### Modal

```
   ┌──────────────────────────┐
   │ Confirm deletion      ✕  │
   ├──────────────────────────┤
   │ Are you sure?            │
   │                          │
   │       [Cancel] [Delete]  │
   └──────────────────────────┘
```

### Calendar grid

```
  Mon Tue Wed Thu Fri Sat Sun
        1   2   3   4   5   6
    7   8   9  10  11  12  13
   14  15 [16] 17  18  19  20
   21  22  23  24  25  26  27
   28  29  30
```

### Toast / Notification

```
┌─────────────────────────────┐
│ ✓  Saved successfully    ✕  │
└─────────────────────────────┘
```

---

## 8. Time / Project

### Gantt

```
Task A  │████────────────│
Task B  │────████████────│
Task C  │────────████████│
Task D  │──────██████────│
         Jan   Feb   Mar
```

### Timeline

```
◆──────◆──────◆──────◆──────◆
Start  Alpha  Beta   RC    GA
2024   Q1     Q2     Q3    Q4
```

### Milestone chain

```
 ●═══════●═══════●═══════●
Kickoff  MVP   Launch   v2.0
```

### Burndown

```
100│●
 80│ ╲●
 60│   ╲●
 40│     ╲●──● (ideal)
 20│       ╲●
  0└──────────────
   W1 W2 W3 W4 W5
```

### Roadmap swimlane

```
          Q1        Q2        Q3        Q4
 Eng    ████──    ──████      ██──    ████──
 Des    ██────    ────██    ████──    ──████
 Mkt    ──────    ████──    ──██──    ██████
```

---

## 9. Specialized

### Venn (approx)

```
  ┌───────┐
  │   A   │
  │   ┌───┼───┐
  └───┼───┘   │
      │   B   │
      └───────┘
```

### Matrix

```
         A   B   C
     ┌             ┐
   A │ 0   1   0   │
   B │ 1   0   1   │
   C │ 0   1   0   │
     └             ┘
```

### Checklist

```
[✓] Draft spec
[✓] Review with team
[▸] Build prototype   ← in progress
[ ] Test
[ ] Ship

Progress: ████████░░ 80%
```

### Railroad / Syntax diagram

```
──▶──( "let" )──▶──( ident )──▶──( "=" )──▶──( expr )──▶──(";")──▶──
```

### Hex grid

```
  ⬡ ⬡ ⬡
 ⬡ ⬡ ⬡ ⬡
  ⬡ ⬡ ⬡
```

### Maze / Labyrinth

```
┌─┬───┬─┐
│ │   │ │
│ │ ┌─┘ │
│   │   │
├─┬─┘ ┌─┤
│ │   │ │
│ └───┘ │
└───────┘
```

### Stack (LIFO)

```
  push ──▶  ┌─────┐  ◀── pop
            │  D  │
            │  C  │
            │  B  │
            │  A  │
            └─────┘
```

### Queue (FIFO)

```
 enqueue ──▶ [ D | C | B | A ] ──▶ dequeue
```

### Tag cloud

```
   python      JAVASCRIPT    go
       rust         TYPESCRIPT
    HASKELL   ocaml    elixir
        zig        kotlin
```

### Quadrant map

```
         Important
            │
   Do   ────┼──── Schedule
            │
 ──Urgent───┼───Not urgent──
            │
 Delegate ──┼──── Delete
            │
       Not important
```

---

## Cross-cutting: Character sets

| Set             | Characters                | Use for                             |
| --------------- | ------------------------- | ----------------------------------- |
| Pure ASCII      | `- \| + / \ * . o`        | Max portability, diffs, plain email |
| Single-line box | `─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼`   | Clean docs, terminals with Unicode  |
| Double-line     | `═ ║ ╔ ╗ ╚ ╝ ╠ ╣ ╦ ╩ ╬`   | Emphasis, headers, borders          |
| Rounded         | `╭ ╮ ╰ ╯`                 | Softer, friendlier UI mockups       |
| Block shading   | `█ ▓ ▒ ░ ▀ ▄ ▐ ▌`         | Density, heatmaps, bars             |
| Arrows          | `→ ← ↑ ↓ ⇒ ⇐ ▶ ◀ ▲ ▼ ↳ ↲` | Flow direction                      |
| Math/misc       | `◆ ● ○ ◯ ⬡ ✓ ✗ ★`         | Nodes, markers, states              |
