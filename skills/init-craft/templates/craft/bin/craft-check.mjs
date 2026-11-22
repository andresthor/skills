#!/usr/bin/env node
// Checks for the craft rules a linter has no rule for; each hit names the rule it breaks.
// The repo's choices (scan roots, skips, which rules) live in bin/craft-check.config.mjs.
import { readdirSync, readFileSync, realpathSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { pathToFileURL } from "node:url";

/** A predicate for `applies`: true for repo-relative paths under any of `dirs`. */
export const under =
  (...dirs) =>
  (path) =>
    dirs.some((d) => path.startsWith(`${d}/`));

// A plan, research note or spike named by its path: the reader of the repo does not have it.
// A section mark alone is not one; `RFC 9110 §15.4` cites a document every reader can open.
const DOC_CITATION = /\bresearch(?:\/|\.md\b| §)|\bplan\.md\b|\bspike\/|\bthe spike\b/;
// Only the shapes that narrate the build match. "The server no longer accepts v1 tokens" and
// "restores the previously focused pane" state present facts and pass.
const BUILD_HISTORY =
  /\bno longer (?:needed|used|necessary|required|called)\b|\b(?:was|were) previously\b|\bpreviously,? (?:this|it|we|they|the|a)\b|\b(?:it|this|that|which|we|they) used to\b|\bused to be\b|\bfor now\b|\bno (?:production )?caller yet\b|\bnot (?:yet )?wired\b/;
// A line number under an upper-case tag for another codebase, or in installed files.
const FOREIGN_LINE_REF = /\b[A-Z]{2,4}\/[\w./-]+\.\w+:\d+|\bnode_modules\/[\w@./-]+:\d+/;

/**
 * Matches a bare id token, given as regex source (`"[A-D]\\d{1,2}"`), only where a build log puts
 * one: the whole comment or the start of a test name, a possessive, a label, a parenthesised,
 * listed or ranged id, or after `pre-`. That spares the same letters and digits in prose, such as
 * `C1 control codes` or `A4 paper`.
 */
export const idToken = (token) =>
  new RegExp(
    [
      String.raw`(?:^|[\s(,/])(?:${token})(?:'s\b|:|\)|,\s*(?:${token})|-(?:${token})|\s*$)`,
      String.raw`^(?:${token})(?![\w.-])`,
      String.raw`\bpre-(?:${token})\b`,
    ].join("|"),
  );

/**
 * The `step-id` rules for one repo's id shapes: one for comments, one for test names. No shape is
 * built in, because each of them (a table row, a protocol phase, a grid cell) is ordinary prose
 * in some other repo. With no shapes it returns no rules.
 */
export function idRules(...shapes) {
  if (shapes.length === 0) return [];
  const test = new RegExp(shapes.map((r) => r.source).join("|"));
  return [
    {
      name: "step-id",
      target: "comment",
      test,
      rule: "a comment names a plan step or scenario id: say what the code does or why, in the repo's own terms",
    },
    {
      name: "step-id",
      target: "test-name",
      test,
      rule: "a test name carries a plan step or scenario id: name the property the test protects",
    },
  ];
}

/**
 * The rule library; a config picks from it, and may override a rule's `applies` by spreading it.
 * A repo's own id shapes come from `idRules`, and any other rule is a plain object of this shape.
 * `applies` takes a repo-relative path with forward slashes (default: every scanned file).
 * `requires` is a RegExp the file's text must match for the rule to apply, for rules that hold
 * only in files with a certain seam. `target` is the text `test` is matched against: the whole
 * line (default), only the comment on it, or only the name given to a `test(...)`, `it(...)`,
 * `describe(...)` or `t.test(...)` call.
 */
export const RULES = {
  emptyCatch: {
    name: "empty-catch",
    test: /\bcatch\s*(?:\([^)]*\))?\s*\{\s*\}|\.catch\(\s*(?:\([^)]*\)|\w+)?\s*=>\s*(?:\{\s*\}|undefined)\s*\)/,
    rule: "swallowed error: an empty catch hides the failure; handle it, or state inside the block why nothing can be done",
  },
  boundaryCast: {
    name: "boundary-cast",
    test: /(?:JSON\.parse\(|\.json\().*\bas\s+(?!unknown\b)[\w{[(]/,
    rule: "cast at the boundary: parse to unknown and narrow, never assert the shape",
  },
  docCitation: {
    name: "doc-citation",
    target: "comment",
    test: DOC_CITATION,
    rule: "a comment cites a plan, research note or spike the repo does not contain: state the reason itself, or delete the comment",
  },
  buildHistory: {
    name: "build-history",
    target: "comment",
    test: BUILD_HISTORY,
    rule: "a comment records build history or unfinished work: state what is true now, in the present tense",
  },
  foreignLineRef: {
    name: "foreign-line-ref",
    target: "comment",
    test: FOREIGN_LINE_REF,
    rule: "a comment points at a line in another codebase or in installed files: name the module and the behaviour, and pin it with a test",
  },
  testNameCitation: {
    name: "test-name-citation",
    target: "test-name",
    test: new RegExp(
      [DOC_CITATION, BUILD_HISTORY, FOREIGN_LINE_REF].map((r) => r.source).join("|"),
    ),
    rule: "a test name carries a citation or build history: name the property the test protects",
  },
};

const TEST_CALL_TAIL = /\b(?:test|it|describe|suite)(?:\.\w+)*\($|\bt\.(?:test|describe)\($/;
// A `/` after one of these starts a regex literal, not a division.
const REGEX_PRECEDERS = new Set([
  "",
  "(",
  ",",
  "=",
  ":",
  "[",
  "!",
  "&",
  "|",
  "?",
  "{",
  "}",
  ";",
  ">",
  "<",
  "+",
  "-",
  "*",
  "%",
  "^",
  "~",
]);
const REGEX_KEYWORD_TAIL = /(?:return|typeof|case|void)$/;

/**
 * One pass over the source, tracking strings, template literals and regex literals so a quote or
 * `//` inside them is not mistaken for a comment. Returns, per line, the comment text on it and
 * the names of the test calls whose name string starts on it.
 */
function scan(text) {
  const lines = text.split("\n").length;
  const comments = Array.from({ length: lines }, () => "");
  const names = Array.from({ length: lines }, () => []);
  let line = 0;
  let tail = ""; // the last code characters, to recognise `test(` before a string
  let last = ""; // the last non-space code character
  for (let i = 0; i < text.length; ) {
    const c = text[i];
    const next = text[i + 1];
    if (c === "\n") {
      line++;
      i++;
    } else if (c === "/" && next === "/") {
      const end = text.indexOf("\n", i);
      const stop = end === -1 ? text.length : end;
      comments[line] += `${text.slice(i, stop)}\n`;
      i = stop;
    } else if (c === "/" && next === "*") {
      const end = text.indexOf("*/", i + 2);
      const stop = end === -1 ? text.length : end + 2;
      const parts = text.slice(i, stop).split("\n");
      parts.forEach((part, k) => {
        comments[line + k] += `${part}\n`;
      });
      line += parts.length - 1;
      i = stop;
    } else if (
      c === '"' ||
      c === "'" ||
      c === "`" ||
      (c === "/" && (REGEX_PRECEDERS.has(last) || REGEX_KEYWORD_TAIL.test(tail)))
    ) {
      let j = i + 1;
      let inClass = false;
      while (j < text.length) {
        if (text[j] === "\\") j++;
        else if (c === "/" && text[j] === "[") inClass = true;
        else if (c === "/" && text[j] === "]") inClass = false;
        else if (text[j] === c && !inClass) break;
        else if (text[j] === "\n" && c !== "`") break;
        j++;
      }
      if (c !== "/" && TEST_CALL_TAIL.test(tail)) names[line].push(text.slice(i + 1, j));
      line += text.slice(i, j).split("\n").length - 1;
      // An unterminated string stops at the newline, which the main loop must still count.
      i = text[j] === c ? j + 1 : j;
      tail = "";
      last = c;
    } else {
      if (!/\s/.test(c)) {
        last = c;
        tail = (tail + c).slice(-40);
      }
      i++;
    }
  }
  return { comments, names };
}

/** Hits for one file's text, as `path:line: rule`. `rules` is a config's rule list. */
export function checkFile(path, text, rules = Object.values(RULES)) {
  const active = rules.filter((r) => (r.applies?.(path) ?? true) && (r.requires?.test(text) ?? true));
  const lines = text.split("\n");
  const { comments, names } = scan(text);
  return lines.flatMap((line, i) =>
    active
      .filter((r) => {
        if (r.target === "comment") return r.test.test((comments[i] ?? "").trim());
        if (r.target === "test-name") return (names[i] ?? []).some((n) => r.test.test(n));
        return r.test.test(line);
      })
      .map((r) => `${path}:${i + 1}: [${r.name}] ${r.rule}`),
  );
}

const sources = (dir, ext) => {
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return []; // a root that does not exist has nothing to check
  }
  return entries.flatMap((e) =>
    e.isDirectory()
      ? e.name === "node_modules"
        ? []
        : sources(join(dir, e.name), ext)
      : ext.test(e.name)
        ? [join(dir, e.name)]
        : [],
  );
};

/** Every hit under the scanned roots of `root`, for a config `{ scan, skip, ext, rules }`. */
export function checkTree(root, { scan: roots, skip = [], ext, rules }) {
  return roots
    .flatMap((d) => sources(join(root, d), ext))
    .map((file) => relative(root, file).split(sep).join("/"))
    .filter((path) => !skip.some((prefix) => path.startsWith(prefix)))
    .flatMap((path) => checkFile(path, readFileSync(join(root, path), "utf8"), rules));
}

// Compared by URL because `import.meta.main` is undefined on older Node, where the gate would pass unrun.
const isMain = process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href;
// Not a top-level await: the config imports this module, so this one must finish evaluating first.
if (isMain) {
  import("./craft-check.config.mjs").then(({ default: config }) => {
    const hits = checkTree(join(import.meta.dirname, ".."), config);
    for (const hit of hits) console.error(hit);
    process.exit(hits.length ? 1 : 0);
  });
}
