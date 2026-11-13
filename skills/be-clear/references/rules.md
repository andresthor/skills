# ASD-STE100 writing rules (condensed)

A working paraphrase of the STE writing rules (Part 1 of the specification), grouped like the standard. It does not reproduce the standard or its dictionary (Part 2). The dictionary has about 900 approved words and about 1,200 unapproved words with approved alternatives. It is the authority for any specific word, and it is a free download from [asd-ste100.org](https://www.asd-ste100.org/).

## Contents

1. Words
2. Noun clusters
3. Verbs
4. Sentences
5. Procedural writing
6. Descriptive writing
7. Safety instructions
8. Punctuation and word counts
9. Writing practices
10. Technical names in software and other fields
11. Substitution table (illustrative)
12. Worked examples

## 1. Words

- **Use approved words, technical names, and technical verbs.** Nothing else.
- **One word, one meaning.** Each approved word has one approved meaning, which can be narrower than in standard English. Example: `follow` means "come after", not "obey". Write "Obey the safety instructions", not "Follow the safety instructions".
- **One word, one part of speech.** Use an approved word only as the part of speech that the dictionary gives. Example: `test` and `check` are approved nouns, not verbs. Write "Do a test of the system" or "Make sure that…", not "Test the system" or "Check the value".
- **Use only the approved forms** of verbs and adjectives (see section 3).
- **Use one name for one thing.** Do not use synonyms for variety. A reader assumes that a new word is a new thing.
- **Use American English spelling.**

## 2. Noun clusters

- **Do not use clusters of more than 3 nouns.** "Database connection pool timeout setting" is too long. Write "the timeout setting of the database connection pool", or define a technical name once and use it.
- If a cluster must stay long because it is a technical name, explain it the first time you use it.
- Use a hyphen between words in a cluster when this makes the relation clear.

## 3. Verbs

- **Approved forms only:** infinitive, imperative, simple present, simple past, simple future (`will`), and the past participle used as an adjective ("the repaired unit").
- **No perfect or progressive tenses.** Write "The job stopped", not "The job has stopped". Write "The service sends data", not "The service is sending data".
- **`-ing` forms only inside technical names** ("the loading screen"). Do not use them as verbs or as nouns made from verbs.
- **Active voice in procedures.** In descriptive text, use the active voice as much as possible. Use the passive only when the actor is unknown or not important.
- **Use a verb for an action, not a noun made from a verb.** Write "Install the package", not "Do the installation of the package". Write "before you accept the unit", not "before acceptance of the unit".
- **Do not make complex verb structures with helping verbs.** Write "The script deletes the file", not "The script will be able to delete the file", unless the time is the point.

## 4. Sentences

- **One topic per sentence.** If a sentence has two topics, make two sentences.
- **Procedural sentences: 20 words or fewer.**
- **Descriptive sentences: 25 words or fewer.**
- **Do not omit words to make a sentence shorter.** Keep articles (`the`, `a`) and the verb. Telegraphic text is ambiguous.
- **Use vertical lists** for complex text, for example for sequences, conditions, or options.
- **Use connecting words and phrases** ("then", "but", "because of this", "thus") to show how sentences relate.

## 5. Procedural writing

- **Write instructions in the imperative (command) form.**
- **One instruction per sentence**, unless two actions must occur at the same time.
- **Put a condition before the command.** Write "If the build fails, stop the release", not "Stop the release if the build fails".
- **Number the steps** when their order is important.
- **Put a warning or caution at the start of the procedure or immediately before the step it applies to.**
- When a step has a result that the reader must see, put the result in a separate sentence after the command ("The status changes to READY.").

## 6. Descriptive writing

- **Give new and complex information slowly**, one idea at a time.
- **Put the key information at the start** of the paragraph and of the sentence.
- **One topic per paragraph. 6 sentences or fewer per paragraph.**
- **Use a topic sentence** that tells the reader what the paragraph is about.
- **Use connecting words** so that the logic between sentences is clear.

## 7. Safety instructions

Use these for any risk, not only physical risk. In software, this includes data loss, downtime, security exposure, cost, and changes that you cannot undo.

- **WARNING:** a risk of injury or death. In software, use it for the most serious risks, for example permanent data loss or a security breach.
- **CAUTION:** a risk of damage to equipment, data, or systems.
- **NOTE:** useful information that is not a risk.
- **Start a warning or caution with a simple, clear command.** Then give a short explanation of the risk. Example: "CAUTION: Do not delete the branch before the merge is complete. If you do, you lose the changes."
- **Do not dilute safety instructions.** Put them where the reader sees them before the action.

## 8. Punctuation and word counts

- **Do not use semicolons.** Make two sentences.
- You can use all other standard punctuation marks. Use the colon to introduce a vertical list. Use parentheses for short references and values, not for important information.
- Use a hyphen for clarity in noun clusters and in compound words.
- **Counting words (this skill's convention):** a number with its unit, a code identifier, a path, a URL, and a hyphenated word each count as one word. Each item of a vertical list counts as a separate sentence.

## 9. Writing practices

- **Do not use phrasal verbs** (verb + preposition with a meaning that is not literal): "set up", "carry out", "look into", "figure out". Use one approved verb: "install", "do", "examine", "find". Phrasal verbs that are the established technical verb of a field (for example "roll back" or "log in" in software) can stay as technical verbs.
- **Be specific.** Write "Tighten the bolt to 12 N·m", not "Tighten the bolt correctly". Write "The query takes 4 s", not "The query is slow".
- **Do not use slang, jargon, or idioms** as general words. Readers who translate cannot decode them.
- **Write sentences that a reader can understand without context.** A reader often goes directly to one step.

## 10. Technical names in software and other fields

STE lets you use words that are not in the dictionary when they belong to a technical-name or technical-verb category. Categories include names of products, parts, tools, materials, processes, units, and the normal terms of the field.

- **Technical names (nouns):** `repository`, `branch`, `endpoint`, `schema`, `token`, `cache`, `container`, `webhook`, product and API names, file and command names.
- **Technical verbs:** verbs that describe a field-specific process, for example `deploy`, `merge`, `compile`, `commit`, `rebase`, `drill`, `ream`.
- **Use a technical name or verb with one meaning** in the whole text. If `deploy` means "put a build on the server", do not also use it for "make a feature available to users".
- **Do not use a technical name as a verb** unless the field uses it as a technical verb. Write "Send a request to the endpoint", not "Endpoint the request".
- **Choose the shortest clear technical name.** Do not use slang as a technical name ("the thingy", "the big job").

## 11. Substitution table (illustrative)

These are common replacements. The first five come from published examples in the specification. The others follow the same principles. The official dictionary is the authority. Look up a word there when the exact ruling is important.

| Instead of | Write |
|---|---|
| acceptable | permitted |
| accessible | get access to |
| check (verb) | do a check, examine, make sure that |
| test (verb) | do a test of |
| follow (meaning "obey") | obey |
| begin, commence, initiate | start |
| rotate | turn |
| ensure, verify | make sure that |
| utilize | use |
| perform, carry out | do |
| obtain, retrieve (general meaning) | get |
| prior to | before |
| subsequent to | after |
| attempt | try |
| assist | help |
| in order to | to |
| set up (general meaning) | install, prepare |
| figure out, determine | find |
| a number of | some, many, or the exact number |

## 12. Worked examples

**Descriptive, strict.**

> Non-STE: The auth service, which is being migrated to the new cluster, has been intermittently timing out, likely due to connection pool exhaustion under load.
>
> STE: The team started to move the auth service to the new cluster. During high load, the auth service sometimes stops because of a timeout. The probable cause is that the connection pool has no free connections.

The progressive and perfect tenses become simple past and simple present. The one long sentence becomes three sentences with one topic each.

**Procedural, strict.**

> Non-STE: To get started, you'll need to clone the repo and then install the dependencies, making sure you're on Node 20.
>
> STE:
> 1. Make sure that Node 20 is installed.
> 2. Clone the repository.
> 3. Install the dependencies.

**Balanced.**

> Non-STE: We should probably hold off on shipping this until QA signs off, since the payment flow changed quite a bit.
>
> STE (balanced): **Recommendation:** do not release this change before QA approves it. The payment flow has large changes, so the risk is high.

The balanced version uses a bold lead-in and joins the reason to its claim with "so". Strict would write "Do not release this change before QA approves it. The payment flow has many changes. Thus, the risk is high."
