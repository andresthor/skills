---
name: be-clear
description: >-
  Write in ASD-STE100 Simplified Technical English (STE) — approved words with one meaning each,
  short active sentences, imperative numbered procedures, and safety notes before the step they
  govern. Use whenever the user mentions ASD-STE100, STE, Simplified Technical English, or
  controlled English, or asks to restate, explain, or document something in that style. With no
  argument it restates your last message in STE. It also draws STE-labeled diagrams, builds a
  navigable self-contained HTML document, and can stay on for a whole orchestration, research,
  ideation, or planning session so every user-facing report follows the standard. Strict by
  default, or "balanced", "80%", or "loosely follow" for more readable output. Not for generic
  "make it simpler" requests that never mention the standard.
argument-hint: "[html|diagram|session] [--strict|--balanced|--loose|--<N>%] [--to <file>] [topic or instructions]"
metadata:
  version: 1.0.0
---

# be-clear

ASD-STE100 exists so a reader who cannot ask a follow-up question still gets one meaning from every sentence. It was built for aircraft maintenance manuals read by non-native speakers. The same property helps anyone who skims, translates, or acts on agent output. This skill applies the standard to whatever the user asks for: a restatement, a diagram, an HTML document, or every report in a session.

The full rule set is in [references/rules.md](references/rules.md). Read it before your first STE output in a conversation. The sections below decide *what* to write and *how strictly*. The rules file decides *how each sentence reads*.

## Parse the invocation

Read three things from the arguments and any free text with them. Explicit free-text instructions win over flags, and flags win over defaults.

| Dial | Values | Default |
|---|---|---|
| **Mode** | restate · topic · diagram · html · session | restate when there is no argument, topic when the free text names content to write |
| **Level** | strict · balanced · loose | strict |
| **Target** | chat, or a file from `--to <path>` | chat (html always writes a file) |

Map natural language onto the dials:

- "html", "web page", "make a document I can browse" → **html**
- "diagram", "draw", "chart the flow", "sketch the architecture" → **diagram**
- "for this session", "from now on", "for all reports", or an invocation at the start of an orchestration, research, ideation, or planning run → **session**
- "save to X", "write it to X", "put it in X" → **target**, the same as `--to X`
- Free text that only sets the level or the target does not change the mode. `/be-clear follow 80% of the standard` and `/be-clear loosely` restate the last message. "Restate this" and "rewrite the above" are also restate.
- A percentage → **level**: 90% and above is strict, 60–89% is balanced, below 60% is loose. "Mostly", "80%", and "don't be pedantic" mean balanced. "Loosely", "STE-flavored", and "in the spirit of" mean loose.

If the mode is still unclear after this, choose the most literal reading and say which one you chose in one line. Do not stop to ask.

## Strictness levels

A named standard means the standard. Strict is the default. The levels relax rules in a fixed order, so "80%" has a concrete meaning. The core tier never relaxes, because those rules carry most of the clarity benefit.

| Rule | strict | balanced | loose |
|---|---|---|---|
| One topic or instruction per sentence | yes | yes | yes |
| Active voice, with the actor named when it is not the reader | yes | yes | yes |
| Procedures as imperative numbered steps, condition before command | yes | yes | yes |
| One term per concept, one meaning per word, in the whole output | yes | yes | yes |
| Warnings and cautions before the step they govern | yes | yes | yes |
| No semicolons | yes | yes | yes |
| Sentence length (20 words procedural, 25 descriptive) | hard limit | up to +5 words | guideline |
| Paragraphs of 6 sentences or fewer, one topic each | yes | yes | guideline |
| Simple verb forms only, no phrasal verbs | yes | common phrasal verbs allowed | relaxed |
| `-ing` forms only inside technical names | yes | allowed where a rewrite is clumsy | relaxed |
| Approved vocabulary | dictionary discipline | replace the known offenders, plain common words allowed | plain common words |
| Noun clusters of 3 words or fewer | yes | yes | guideline |
| Keep articles, do not drop words to save length | yes | yes | relaxed in headings and tables |
| Presentation (headings, bold lead-ins, tables, a short orienting intro) | plain and functional | allowed freely | encouraged |

Balanced and loose exist so the output is pleasant to read. Spend the freed room on structure and flow, not on longer or vaguer sentences.

## What never changes

These hold in every mode and level. Breaking any of them makes the output wrong, not only non-compliant.

- **Full fidelity.** STE changes how a thing is said, never what is said. Keep every fact, number, path, name, decision, caveat, and open question. STE output is often *longer* than the source, and that is correct.
- **Verbatim zones.** Code, commands, identifiers, file paths, URLs, quoted error messages, and quoted speech stay exactly as they are. Write the sentence around them in STE.
- **Technical names and technical verbs are allowed at every level.** Product names, API names, and the normal terms of the field (`repository`, `branch`, `deploy`, `merge`, `token`, `schema`) are STE technical names or technical verbs. Use each one with one meaning, and do not replace them with dictionary words that lose precision.
- **No new content.** Do not add opinions, recommendations, or summaries that the source did not have. In restate mode this applies strictly.
- **No meta-commentary.** Do not explain that the text is in STE, list the rules you applied, or apologize for length. One short label line is enough when the user needs to know which text is the restatement.

## Modes

### Restate (no argument)

1. Find the target. It is your most recent substantive message before this invocation. Ignore tool output and the invocation itself. If there is no such message, ask what to restate.
2. Make a quick inventory of the facts in the target: numbers, names, paths, decisions, caveats, and questions to the user. Keep this inventory in your reasoning.
3. Rewrite. Classify each block as procedure (steps the reader does), description (how a thing is or works), or safety (a risk to data, money, systems, or people). Each type has its own rules in the rules file. Keep the original order, except where STE requires a condition or a warning to come first.
4. Compare the result to the inventory. Put back anything that is missing.
5. With `--to <path>`, write the result to that file and give the path in one line. If not, reply with the result in chat.

### Topic (free text only)

Do the requested work, for example answer the question or explain the system, and write the answer in STE from the start. Do not write a normal draft first and convert it. A draft in STE from the start has a cleaner structure.

### Diagram

Draw the diagram the user asks for. Use ASCII in chat by default. Use Mermaid or another format only when the user asks for it or the target file type expects it. If a diagram skill or project convention is available, use its drawing conventions. STE controls the words only.

- **Labels** are technical names or short noun phrases of 3 words or fewer. Use the same label for the same thing everywhere.
- **Arrow labels** are approved verbs in the simple present, for example `sends`, `starts`, `stops`, `reads`, `writes`.
- **After the diagram**, write a short description of 6 sentences or fewer. For a flow, write numbered steps instead. The text must use the same labels as the diagram.
- With `--to <path>`, write the diagram and its text to the file. If not, show them in chat.

### HTML document

Build one self-contained, easily navigable HTML file in STE that contains the information the user asked for.

1. Write the content first, in STE, as a section outline. Use one topic per section, numbered sections, procedures as numbered steps, and safety notes before their steps.
2. Copy [assets/template.html](assets/template.html) and fill it. The comment at the top of the template lists the placeholders and the component markup: sections, procedure steps, WARNING / CAUTION / NOTE callouts, tables, and a glossary of technical names.
3. Keep the file self-contained. Do not use network fonts, CDNs, or external scripts. It must work offline and print cleanly.
4. Choose the output path in this order: `--to <path>`, then a generated-docs location from the project's agent instructions (AGENTS.md, CLAUDE.md, or similar), then `./<slug>.html`. Give the path to the user in one line.

Add a glossary when the document uses more than a few technical names. In STE, readers depend on each term having one meaning, so a glossary is a navigation aid, not decoration.

### Session

The user wants every user-facing output from now on in STE. This often happens at the start of an orchestration, a research or planning run, or an ideation session.

1. **Record the mode where it can survive context compaction.** Add a line such as `STE mode on — level: balanced — exit: "stop STE"` to your task list, plan file, or other durable working notes. Read it again before each report. Without it, the mode silently disappears when the context is summarized.
2. **Confirm in one line,** in STE, with the level and the exit phrase. Then continue with the actual work.
3. **In scope:** every prose reply, progress update, question to the user, plan, report, or document written for the user, and the final synthesis. Subagent results that you relay to the user are also in scope.
4. **Out of scope:** code, config, commands, tool inputs, quoted material, and prompts between agents. Commit messages and PR text also stay out of scope unless the user asks for them, because they follow their own conventions.
5. **Subagents.** Convert subagent output to STE when you synthesize it. Do not send the full rules file to subagents. When a subagent writes a file that goes directly to the user, put the brief below in its prompt.
6. **Other skills.** When another skill controls the structure of the output (a planner, an orchestrator, a review template), keep its structure. STE controls only the language inside it. When both have a rule for the same thing, use the stricter rule.
7. **Exit** when the user says "stop STE", "normal style", or similar. A new invocation with a different level changes the level. Update the durable note in both cases.

Brief for subagents (give it word for word):

> Write all prose in this file in ASD-STE100 Simplified Technical English, level `<level>`. Use one topic per sentence. Use active voice. Write procedures as numbered imperative steps, with the condition before the command. Keep sentences to 20 words for procedures and 25 words for descriptions. Use one term for each concept. Put warnings before the step they apply to. Do not use semicolons. Keep code, paths, and quotes exactly as they are.

## Self-check before you send

Do this check on every STE output. It is short because the most frequent defects are few.

- Sentences that look long: count the words. Split at the second topic.
- Passive voice in instructions: name the actor and make the verb active.
- `-ing` verb forms and perfect tenses (strict level): change to simple present, simple past, or imperative.
- Terms: make sure that each concept has one name in the whole output, headings included.
- Procedures: make sure that each step is one action (or simultaneous actions) and that conditions and warnings come first.
- Known unapproved words from the substitution table in the rules file.
- Fidelity: make sure that no fact from the source is missing.

## Example (strict)

Source:

> Before kicking off the migration, it's worth making sure the backup has actually completed — if it hasn't, you'll want to hold off, since rolling back without one is basically impossible.

STE:

> CAUTION: Do not start the migration before the backup is complete. Without a backup, you cannot restore the data.
>
> 1. Make sure that the backup is complete.
> 2. Start the migration.

The source has one risk, one condition, and one action. The STE version gives each one its own position. The caution comes first, starts with a command, and then gives the risk. The steps follow.
