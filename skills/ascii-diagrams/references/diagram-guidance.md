## Picking the right diagram type

The core move: **name the relationship you're trying to show before you pick a shape.** Most bad diagrams come from reaching for a familiar form (boxes-and-arrows, tree) and stuffing the content in, instead of asking what structure the content actually has.

**1. Identify the primary relationship.** Each diagram family encodes one thing well:

| If the relationship is… | Use… |
|---|---|
| Containment / composition | Nested boxes, tree |
| Direction / sequence over time | Flow, sequence, timeline |
| State changes | State machine |
| Quantity / comparison | Bar, histogram, heatmap |
| Dependency (not temporal) | DAG, call graph |
| Structure of data in memory/bytes | Bit field, memory layout |
| Layout in 2D space | Wireframe, grid |
| Set membership | Venn, quadrant |

If two relationships matter equally, you probably need two diagrams, not one clever one.

**2. Match the diagram's dimensionality to the data's.** A sequence diagram has two axes (actors × time). A bar chart has one (categories). A heatmap has two (row × column × intensity). If you're using a 2D form to show 1D data, you're wasting space; if you cram 3D data into a 2D form, you're lying by omission. Flow diagrams are especially abused this way — people draw a DAG and call it a flow, hiding the fact that there's no real temporal order.

**3. Let the audience's question drive it.** "How does X work?" → sequence or flow. "What depends on what?" → DAG. "Where is the bottleneck?" → bar/heatmap. "What are the states?" → state machine. "What does the system look like?" → architecture/C4. If you can't state the reader's question in one sentence, the diagram will be vague.

**4. Respect the rendering medium.** Pure ASCII for git diffs, code comments, and plain-text emails. Box-drawing for markdown docs rendered in a monospace viewer. Anything involving `╔ ═ █` should stay in docs you control — they break in terminals without good font fallback, in search results, and when someone copy-pastes into Slack. Block shading in particular renders wildly differently across fonts.

**5. Prefer fewer, bigger diagrams over many small ones — but not one mega-diagram.** Rule of thumb: if a diagram has more than ~15 nodes or ~7 swimlanes, split it by level of abstraction (C4's idea: context → container → component → code). A single diagram trying to show all four levels at once is unreadable at any size.

**6. Kill decorative elements ruthlessly.** Shadows, 3D, rounded corners, double-borders — they carry visual weight but no information. Each glyph should either represent something or disambiguate structure. If you can't say what a `╔` means that `┌` doesn't, use `┌`.

**7. Test it by reading it cold.** Look at the diagram tomorrow, or show it to someone not in the conversation. If they can't reconstruct the relationship in <10 seconds, the form is wrong — not the labels.

**Opinion, contrarian angle:** a lot of technical writing over-indexes on diagrams. A five-line bulleted list of dependencies is often clearer than the DAG. A sentence like "the request flows: client → gateway → auth → service → DB" beats most sequence diagrams for simple cases. Diagrams earn their keep when the structure is genuinely non-linear or when spatial arrangement communicates something prose can't — branching, cycles, parallelism, relative magnitudes. For strictly linear or small-N stuff, prose wins on information density.
