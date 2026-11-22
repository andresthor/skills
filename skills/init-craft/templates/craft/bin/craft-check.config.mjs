// Repo choices for bin/craft-check.mjs. Pick rules from RULES; narrow one with `applies` by
// spreading it, and add repo rules as `{ name, test, rule, applies?, langs?, requires?, target? }`.
import { idRules, RULES, under } from "./craft-check.mjs";

// The shapes of the ids this repo's plans and notes use, if any; they feed the `step-id` rules.
// With idToken imported: [idToken("[A-D]\\d{1,2}"), /\b[Ss]lice [A-D]\b/, /\b(?:[Rr]ow|[Ss]cenario) \d+[a-z]?\b/]
const ID_SHAPES = [];

// Tests may swallow an error on purpose, and this checker's own test quotes such lines.
const inTests = under("test", "tests");
const outsideTests = (path) => !inTests(path);

export default {
  // Keep the roots this repo has; one that does not exist is ignored. Typical choices:
  //   TypeScript: ["src", "bin", "scripts", "test"]
  //   Python:     ["src", "scripts", "tests", "bin", "test"]
  //   Go:         ["."] (dot-directories below a root are never entered)
  scan: ["src", "lib", "bin", "scripts", "test", "tests"],
  // Vendored code and recorded fixtures are not ours to police. A Go repo scanned from "."
  // adds "vendor/"; a Rust one adds "target/".
  skip: ["test/fixtures/", "tests/fixtures/"],
  // Without `ext`, every file whose language the engine knows is checked. To narrow it:
  //   TypeScript: ext: /\.(?:[cm]?[jt]s|tsx)$/,
  //   Python:     ext: /\.pyi?$/,
  //   Go:         ext: /\.go$/,
  rules: [
    // Each of these three holds in its own languages only (see `langs`); drop the ones this repo has none of.
    { ...RULES.emptyCatch, applies: outsideTests },
    { ...RULES.boundaryCast, applies: outsideTests },
    { ...RULES.emptyHandler, applies: outsideTests },
    RULES.docCitation,
    RULES.buildHistory,
    RULES.foreignLineRef,
    RULES.testNameCitation,
    ...idRules(...ID_SHAPES),
  ],
};
