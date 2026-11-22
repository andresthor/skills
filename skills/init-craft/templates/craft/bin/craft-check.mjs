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
const FOREIGN_LINE_REF =
  /\b[A-Z]{2,4}\/[\w./-]+\.\w+:\d+|\bnode_modules\/[\w@./-]+:\d+|(?:\bsite-packages|\bvendor|\bpkg\/mod|\.cargo\/registry)\/[\w@./-]+\.\w+:\d+/;

/**
 * Matches a bare id token, given as regex source (`"[A-D]\\d{1,2}"`), only where a build log puts
 * one: the whole comment or the start of a test name, a possessive, a label, a parenthesised,
 * listed or ranged id, or after `pre-`. That spares the same letters and digits in prose, such as
 * `C1 control codes` or `A4 paper`.
 */
export const idToken = (token) =>
  new RegExp(
    [
      String.raw`(?:^|[\s(,/#])(?:${token})(?:'s\b|:|\)|,\s*(?:${token})|-(?:${token})|\s*$)`,
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

const breaks = (s) => s.split("\n").length - 1;
const anyComment = (comments, from, to) => comments.slice(from, to + 1).some(Boolean);

// A comment on the handler or in its body states why nothing is done, so only bare ones are hits.
function emptyExcepts({ code, comments }) {
  const hits = [];
  code.forEach((line, i) => {
    const m = /^(\s*)except\b[^:]*:\s*(.*)$/.exec(line);
    if (!m) return;
    const body = m[2].trim() ? [m[2]] : [];
    let end = i;
    for (let j = i + 1; !m[2].trim() && j < code.length; j++) {
      if (!code[j].trim()) continue;
      if (code[j].search(/\S/) <= m[1].length) break;
      body.push(code[j]);
      end = j;
    }
    const idle = body.length > 0 && body.every((s) => /^\s*(?:pass|\.\.\.)\s*$/.test(s));
    if (idle && !anyComment(comments, i, end)) hits.push(i);
  });
  return hits;
}

function emptyErrChecks({ code, comments }) {
  const text = code.join("\n");
  const hits = [];
  for (const m of text.matchAll(/\bif\b[^{}\n]*\berr\s*!=\s*nil\s*\{\s*\}/g)) {
    const from = breaks(text.slice(0, m.index));
    if (!anyComment(comments, from, from + breaks(m[0]))) hits.push(from);
  }
  code.forEach((line, i) => {
    if (/^\s*_\s*=\s*err\s*$/.test(line) && !comments[i]) hits.push(i);
  });
  return hits;
}

const EMPTY_HANDLERS = { python: emptyExcepts, go: emptyErrChecks };

/**
 * The rule library; a config picks from it, and may override a rule's `applies` by spreading it.
 * A repo's own id shapes come from `idRules`, and any other rule is a plain object of this shape.
 * `applies` takes a repo-relative path with forward slashes (default: every scanned file).
 * `langs` lists the languages a rule holds in, by the keys of `LANGUAGES` (default: every file).
 * `requires` is a RegExp the file's text must match for the rule to apply, for rules that hold
 * only in files with a certain seam. `target` is the text `test` is matched against: the whole
 * line (default), only the comment on it, or only the name of a test that starts on it. A rule
 * that needs more than one line gives `find` in place of `test`: it takes the scanned file
 * (`{ path, lang, lines, code, comments, names }`, one entry per line, `code` without comments
 * and with every string emptied) and returns the indexes of the lines that break the rule.
 */
export const RULES = {
  emptyCatch: {
    name: "empty-catch",
    langs: ["js"],
    test: /\bcatch\s*(?:\([^)]*\))?\s*\{\s*\}|\.catch\(\s*(?:\([^)]*\)|\w+)?\s*=>\s*(?:\{\s*\}|undefined)\s*\)/,
    rule: "swallowed error: an empty catch hides the failure; handle it, or state inside the block why nothing can be done",
  },
  boundaryCast: {
    name: "boundary-cast",
    langs: ["js"],
    test: /(?:JSON\.parse\(|\.json\().*\bas\s+(?!unknown\b)[\w{[(]/,
    rule: "cast at the boundary: parse to unknown and narrow, never assert the shape",
  },
  emptyHandler: {
    name: "empty-handler",
    langs: Object.keys(EMPTY_HANDLERS),
    find: (source) => EMPTY_HANDLERS[source.lang](source),
    rule: "swallowed error: an empty handler hides the failure; handle it, or state inside the block why nothing can be done",
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

// A `/` after one of these starts a regex literal, not a division.
const REGEX_PRECEDERS = new Set("( , = : [ ! & | ? { } ; > < + - * % ^ ~".split(" ").concat(""));
const REGEX_KEYWORD_TAIL = /\b(?:return|typeof|case|void)\s?$/;

const ANYWHERE = () => true;
// `$#`, `${#x}` and `a#b` are not comments: a shell or YAML `#` opens one only at a word start.
const AT_WORD_START = (prev) => prev === undefined || /[\s;|&(]/.test(prev);
const SLASH = { slash: true, quotes: "\"'" };
const HASH = { hash: AT_WORD_START, quotes: "\"'", raw: "'" };

/**
 * How to find comments, strings and test names per language. `ext` and `names` pick the language
 * of a file. `slash` is `//` and block comments (`nested` where they nest); `hash` says whether a
 * `#` opens a comment, given the characters around it. `quotes` open strings: those in `multiline`
 * may span lines, those in `raw` take no backslash escapes, and `triple` adds triple-quoted ones.
 * `testCall` matches the code right before a string that names a test; `testDef` captures a test
 * function's name, counted only after a line matching `testAttr` where one is given.
 */
export const LANGUAGES = {
  js: {
    ext: "js jsx ts tsx mjs cjs mts cts",
    ...SLASH,
    quotes: "\"'`",
    multiline: "`",
    regex: true,
    testCall: /\b(?:test|it|describe|suite)(?:\.\w+)*\s?\(\s?$|\bt\.(?:test|describe)\(\s?$/,
  },
  go: {
    ext: "go",
    ...SLASH,
    quotes: "\"'`",
    multiline: "`",
    raw: "`",
    testCall: /\b[tb]\.Run\(\s?$/,
    testDef: /^func\s+Test(\w+)\s*\(/,
  },
  rust: {
    ext: "rs",
    ...SLASH,
    quotes: '"',
    multiline: '"',
    nested: true,
    rust: true,
    testAttr: /^\s*#\[(?:\w+::)*test\b/,
    testDef: /\bfn\s+(\w+)/,
  },
  java: { ext: "java", ...SLASH, triple: true },
  kotlin: { ext: "kt kts", ...SLASH, triple: true, nested: true },
  swift: { ext: "swift", ...SLASH, quotes: '"', triple: true, nested: true },
  c: { ext: "c h cc cpp hpp", ...SLASH },
  csharp: { ext: "cs", ...SLASH },
  // `#[Attribute]` is code; any other `#` opens a comment.
  php: { ext: "php", ...SLASH, hash: (_prev, next) => next !== "[" },
  python: {
    ext: "py pyi",
    hash: ANYWHERE,
    quotes: "\"'",
    triple: true,
    testDef: /^\s*(?:async\s+)?def\s+test_(\w+)/,
  },
  ruby: {
    ext: "rb",
    hash: AT_WORD_START,
    quotes: "\"'",
    interpolation: true,
    heredoc: true,
    beginEnd: true,
    testCall: /(?:^|[^\w.])(?:RSpec\.)?(?:it|describe|context|specify|test)[ (]$/,
  },
  shell: {
    ext: "sh bash zsh",
    ...HASH,
    multiline: "\"'",
    escapes: true,
    heredoc: true,
  },
  toml: { ext: "toml", ...HASH, hash: ANYWHERE, triple: true },
  yaml: { ext: "yaml yml", ...HASH },
  make: { names: "Makefile GNUmakefile", ...HASH },
  docker: { names: "Dockerfile", ...HASH },
};

const byWord = (key) =>
  new Map(
    Object.entries(LANGUAGES).flatMap(([lang, syntax]) =>
      (syntax[key] ?? "").split(" ").filter(Boolean).map((word) => [word, lang]),
    ),
  );
const BY_EXT = byWord("ext");
const BY_NAME = byWord("names");
const SHEBANG = /^#!.*?\b(sh|bash|zsh|dash|ksh|python|ruby|node)[\d.]*(?:\s|$)/;
const INTERPRETERS = { python: "python", ruby: "ruby", node: "js" };

/**
 * The key in `LANGUAGES` for a file, or null: by extension, then by file name, and for a file
 * with no extension by the interpreter its `#!` line names.
 */
export function languageOf(path, text = "") {
  const name = path.slice(path.lastIndexOf("/") + 1);
  const dot = name.lastIndexOf(".");
  if (dot > 0) return BY_EXT.get(name.slice(dot + 1)) ?? null;
  if (BY_NAME.has(name)) return BY_NAME.get(name);
  const shebang = SHEBANG.exec(text.split("\n", 1)[0]);
  return shebang ? (INTERPRETERS[shebang[1]] ?? "shell") : null;
}

/** Where the body of the string opened at `i` ends, and where the scan resumes after it. */
function stringEnd(text, i, syntax) {
  const quote = text[i];
  const fence = quote.repeat(3);
  if (syntax.triple && text.startsWith(fence, i)) {
    let j = i + 3;
    while (j < text.length && !text.startsWith(fence, j)) j += text[j] === "\\" ? 2 : 1;
    return [i + 3, Math.min(j, text.length), Math.min(j + 3, text.length)];
  }
  // Shell `$'...'` takes escapes though a plain single-quoted string does not.
  const raw = syntax.raw?.includes(quote) && text[i - 1] !== "$";
  const multiline = syntax.multiline?.includes(quote);
  let j = i + 1;
  for (; j < text.length; j++) {
    const c = text[j];
    if (c === quote || (c === "\n" && !multiline)) break;
    if (c === "\\" && !raw) j++;
    else if (syntax.interpolation && quote === '"' && c === "#" && text[j + 1] === "{") {
      // Quotes inside `#{...}` belong to the expression, not to the string around it.
      for (let depth = 0; j < text.length && text[j] !== "\n"; j++) {
        if (text[j] === "{") depth++;
        else if (text[j] === "}" && --depth === 0) break;
      }
    }
  }
  j = Math.min(j, text.length);
  // An unterminated string stops at the newline, which the main loop must still count.
  return [i + 1, j, text[j] === quote ? j + 1 : j];
}

const RUST_RAW = /r(#*)"/y;
const HEREDOC = /<<[-~]?(['"]?)([A-Za-z_]\w*)\1/y;
const words = (id) => id.replace(/_+/g, " ").replace(/([a-z0-9])([A-Z])/g, "$1 $2").trim();

/**
 * One pass over the source, tracking the language's strings (and regex literals in JS) so a quote
 * or comment marker inside them is not mistaken for a comment. Returns, per line, the comment
 * text on it, the names of the tests that start on it, and its code with every string emptied.
 */
function scan(text, syntax) {
  const perLine = (make) => Array.from({ length: breaks(text) + 1 }, make);
  const out = { comments: perLine(() => ""), names: perLine(() => []), code: perLine(() => "") };
  if (!syntax) return { ...out, code: text.split("\n") };
  let line = 0;
  let tail = ""; // the last code characters, to recognise `test(` before a string
  let last = ""; // the last non-space code character
  let heredoc = "";
  const eol = (i) => {
    const end = text.indexOf("\n", i);
    return end === -1 ? text.length : end;
  };
  const code = (s) => {
    out.code[line] += s;
    if (s.trim()) {
      last = s.at(-1);
      tail = (tail + s).slice(-40);
    } else if (!tail.endsWith(" ")) tail += " ";
  };
  const comment = (from, to) => {
    const parts = text.slice(from, to).split("\n");
    parts.forEach((part, k) => {
      out.comments[line + k] += `${part}\n`;
    });
    line += parts.length - 1;
    return to;
  };
  const literal = (open, [from, to, next], named = true) => {
    if (named && syntax.testCall?.test(tail)) out.names[line].push(text.slice(from, to));
    out.code[line] += '""';
    line += breaks(text.slice(open, next));
    tail = "";
    last = '"';
    return next;
  };
  // A `#!` line is not code in any language, and in JS its slashes would read as a regex.
  for (let i = syntax.slash && text.startsWith("#!") ? eol(0) : 0; i < text.length; ) {
    const c = text[i];
    const next = text[i + 1];
    const prev = text[i - 1];
    if (c === "\n") {
      const word = heredoc;
      heredoc = "";
      const end = word && new RegExp(String.raw`\n[ \t]*${word}[ \t]*(?=\n|$)`).exec(text.slice(i));
      if (end) {
        // The body of a here-document is data: neither code nor comments.
        const stop = i + end.index + end[0].length;
        line += breaks(text.slice(i, stop));
        i = stop;
      } else {
        line++;
        i++;
        if (!tail.endsWith(" ")) tail += " ";
      }
    } else if (syntax.slash && c === "/" && next === "/") {
      i = comment(i, eol(i));
    } else if (syntax.slash && c === "/" && next === "*") {
      let j = i + 2;
      for (let depth = 1; j < text.length && depth > 0; ) {
        const opens = syntax.nested && text.startsWith("/*", j);
        const closes = text.startsWith("*/", j);
        depth += opens ? 1 : closes ? -1 : 0;
        j += opens || closes ? 2 : 1;
      }
      i = comment(i, Math.min(j, text.length));
    } else if (syntax.hash && c === "#" && syntax.hash(prev, next)) {
      i = comment(i, eol(i));
    } else if (syntax.beginEnd && (prev ?? "\n") === "\n" && text.startsWith("=begin", i)) {
      const end = text.indexOf("\n=end", i);
      i = comment(i, end === -1 ? text.length : eol(end + 1));
    } else if (syntax.rust && c === "'") {
      // A quote right after one character or one escape closes a char literal; else it is a lifetime.
      const wide = text.codePointAt(i + 1) > 0xffff;
      const close = next === "\\" ? text.indexOf("'", i + 3) : i + (wide ? 3 : 2);
      if (text[close] === "'") i = literal(i, [i + 1, close, close + 1]);
      else {
        code(c);
        i++;
      }
    } else if (syntax.rust && c === "r" && !/\w/.test(text[i - (/[bc]/.test(prev ?? "") ? 2 : 1)] ?? "") && rawAt(i)) {
      const opener = rawAt(i);
      const fence = `"${opener[1]}`;
      const from = i + opener[0].length;
      const end = text.indexOf(fence, from);
      const to = end === -1 ? text.length : end;
      i = literal(i, [from, to, Math.min(to + fence.length, text.length)]);
    } else if (syntax.regex && c === "/" && (REGEX_PRECEDERS.has(last) || REGEX_KEYWORD_TAIL.test(tail))) {
      let j = i + 1;
      for (let inClass = false; j < text.length && text[j] !== "\n"; j++) {
        if (text[j] === "\\") j++;
        else if (text[j] === "[") inClass = true;
        else if (text[j] === "]") inClass = false;
        else if (text[j] === "/" && !inClass) break;
      }
      j = Math.min(j, text.length);
      i = literal(i, [i + 1, j, text[j] === "/" ? j + 1 : j], false);
    } else if (syntax.quotes.includes(c)) {
      i = literal(i, stringEnd(text, i, syntax));
    } else if (syntax.escapes && c === "\\" && next !== undefined && next !== "\n") {
      code(c + next);
      i += 2;
    } else if (syntax.heredoc && c === "<" && prev !== "<" && heredocAt(i)) {
      const opener = heredocAt(i);
      heredoc = opener[2];
      code(opener[0]);
      i += opener[0].length;
    } else {
      code(c);
      i++;
    }
  }
  if (syntax.testDef) {
    let marked = !syntax.testAttr;
    out.code.forEach((codeLine, i) => {
      if (syntax.testAttr?.test(codeLine)) marked = true;
      const def = marked && syntax.testDef.exec(codeLine);
      if (def) out.names[i].push(words(def[1]));
      // Further attributes and blank lines may sit between the marker and its function.
      if (def || (codeLine.trim() && !/^\s*#!?\[/.test(codeLine))) marked = !syntax.testAttr;
    });
  }
  return out;

  function rawAt(i) {
    RUST_RAW.lastIndex = i;
    return RUST_RAW.exec(text);
  }
  function heredocAt(i) {
    HEREDOC.lastIndex = i;
    return HEREDOC.exec(text);
  }
}

/** Hits for one file's text, as `path:line: rule`. `rules` is a config's rule list. */
export function checkFile(path, text, rules = Object.values(RULES)) {
  const lang = languageOf(path, text);
  const active = rules.filter(
    (r) => (r.langs?.includes(lang) ?? true) && (r.applies?.(path) ?? true) && (r.requires?.test(text) ?? true),
  );
  const lines = text.split("\n");
  const source = { path, lang, lines, ...scan(text, LANGUAGES[lang]) };
  const found = new Map(active.filter((r) => r.find).map((r) => [r, new Set(r.find(source))]));
  return lines.flatMap((line, i) =>
    active
      .filter((r) => {
        if (r.find) return found.get(r).has(i);
        if (r.target === "comment") return r.test.test(source.comments[i].trim());
        if (r.target === "test-name") return source.names[i].some((n) => r.test.test(n));
        return r.test.test(line);
      })
      .map((r) => `${path}:${i + 1}: [${r.name}] ${r.rule}`),
  );
}

// Installed and generated trees are not the repo's code; a dot-directory is checked only as a scan root.
const SKIPPED_DIR = /^(?:node_modules|__pycache__|\..*)$/;

const sources = (dir) => {
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return []; // a root that does not exist has nothing to check
  }
  return entries.flatMap((e) =>
    e.isDirectory() ? (SKIPPED_DIR.test(e.name) ? [] : sources(join(dir, e.name))) : [join(dir, e.name)],
  );
};

/**
 * Every hit under the scanned roots of `root`, for a config `{ scan, skip, ext, rules }`. Without
 * `ext`, every file whose language `languageOf` knows is checked.
 */
export function checkTree(root, { scan: roots, skip = [], ext, rules }) {
  return roots
    .flatMap((d) => sources(join(root, d)))
    .map((file) => relative(root, file).split(sep).join("/"))
    .filter((path) => !skip.some((prefix) => path.startsWith(prefix)))
    .flatMap((path) => {
      const name = path.slice(path.lastIndexOf("/") + 1);
      // A file with an extension is settled by its name; one without needs its `#!` line read.
      if (ext ? !ext.test(name) : name.lastIndexOf(".") > 0 && !languageOf(path)) return [];
      const text = readFileSync(join(root, path), "utf8");
      return ext || languageOf(path, text) ? checkFile(path, text, rules) : [];
    });
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
