// Repo choices for bin/craft-check.mjs. Pick rules from RULES; narrow one with `applies` by
// spreading it, and add repo rules as `{ name, test, rule, applies?, requires?, target? }`.
import { idRules, RULES, under } from "./craft-check.mjs";

// The shapes of the ids this repo's plans and notes use, if any; they feed the `step-id` rules.
// With idToken imported: [idToken("[A-D]\\d{1,2}"), /\b[Ss]lice [A-D]\b/, /\b(?:[Rr]ow|[Ss]cenario) \d+[a-z]?\b/]
const ID_SHAPES = [];

export default {
  scan: ["src", "bin", "scripts", "test"],
  // Vendored code and recorded fixtures are not ours to police.
  skip: ["test/fixtures/"],
  ext: /\.(?:[cm]?[jt]s|tsx)$/,
  rules: [
    { ...RULES.emptyCatch, applies: under("src", "bin", "scripts") },
    { ...RULES.boundaryCast, applies: under("src", "bin", "scripts") },
    RULES.docCitation,
    RULES.buildHistory,
    RULES.foreignLineRef,
    { ...RULES.testNameCitation, applies: under("test") },
    ...idRules(...ID_SHAPES),
  ],
};
