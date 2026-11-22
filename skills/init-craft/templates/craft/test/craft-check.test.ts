import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import config from "../bin/craft-check.config.mjs";
import { checkFile, checkTree, idRules, idToken, RULES, under } from "../bin/craft-check.mjs";

// An invented repo's id shapes: the engine has none, and the repo's config is free to differ
const ID_SHAPES = [
  idToken(String.raw`[A-D]\d{1,2}|S\d{1,2}`),
  /\b[Ss]lice [A-D]\b/,
  /\b(?:[Rr]ow|[Ii]nvariant|[Ss]cenario) \d+[a-z]?\b/,
];
const BUILT_IN = Object.values(RULES);
const WITH_IDS = [...BUILT_IN, ...idRules(...ID_SHAPES)];

const fired = (path: string, text: string, rules = WITH_IDS) =>
  checkFile(path, text, rules).map((hit) => hit.slice(hit.indexOf("[") + 1, hit.indexOf("]")));
const hits = (path: string, text: string) => fired(path, text).length;

// Each rule must fire on a bad line and stay quiet on a good one, or a regex typo disables it silently
const CASES: { rule: string; path: string; bad: string[]; good: string[] }[] = [
  {
    rule: "empty-catch",
    path: "src/x.ts",
    bad: ["try { f(); } catch {}", "} catch (e) { }", "p.catch(() => {});", "p.catch((e) => {})"],
    good: [
      "} catch { /* the pipe is gone; the exit path reports it */ }",
      "} catch (e) {",
      "p.catch(() => { /* a dead pipe; the exit path reports it */ });",
    ],
  },
  {
    rule: "boundary-cast",
    path: "src/x.ts",
    bad: [
      "const m = JSON.parse(s) as Message;",
      "const m = JSON.parse(String(x)) as Message;",
      "const m = (await r.json()) as Message;",
      "const m = (await r.json()) as { a: 1 };",
    ],
    good: ["const m: unknown = JSON.parse(s);", "const m = JSON.parse(s) as unknown;"],
  },
  {
    rule: "doc-citation",
    path: "src/x.ts",
    bad: [
      "// see research/03-options.md for the table",
      "/** Per research §3. */",
      "/** the plan.md recipe */",
      "const a = 1; // the spike showed this",
      "// ported from spike/prototype.mjs",
    ],
    good: [
      "// The research agent's output is untrusted",
      "const doc = 'research/03.md'; // a string, not a comment",
      "// README.md lists the flags; docs/01-intro.md has the tour",
      "// a spike in latency",
      "// RFC 9110 §15.4: a 304 has no body",
    ],
  },
  {
    rule: "step-id",
    path: "test/unit/x.test.ts",
    bad: [
      "// B6",
      "// Opens the session (B4) before the bind",
      "/** A8's loader owns this. */",
      "// S7: a patch mismatch",
      "// slice C maps this",
      "// row 9a of the table",
      "// invariant 15 holds here",
      "// pre-A8 stubs",
      "// scenario 4 covers it",
      "// ids B3-B14 are listed",
      'test("S54: an answer maps to its label", () => {});',
      "test(`A1: defers to the loader`, () => {});",
      "  test.skip('row 9a: held', () => {});",
      'describe("invariant 9", () => {});',
      'test(\n  "S20: every entry has a title",',
      '  await t.test("S1: subtest", async () => {});',
      "for (const c of cases) { test(`S9: ${c}`, () => {}); }",
    ],
    good: [
      "// Node 22.1 and later; HTTP 404 is passed through",
      "// a slice of the array; the next phase of the shutdown",
      "// C1 control codes 0x80-0x9f",
      "// uploads to S3 or GCS; A4 paper; the L1 cache; B2B and E2E",
      "// version 1.3.0, status 404, exit code -1, ES2022",
      "// ABC1 and FOO-A1 are not ids",
      "const id = 'B4'; // the string is not a comment",
      "// test('S1: only a comment', () => {})",
      'const s = "S1: not a test call";',
      'const t = `\ntest("S1: inside a template")`;',
      'test("handles C1 control codes and S3 keys", () => {});',
    ],
  },
  {
    rule: "build-history",
    path: "src/x.ts",
    bad: [
      "// no longer needed",
      "// previously this threw",
      "// it used to return null",
      "// no production caller yet",
      "// not yet wired to the session",
      "// kept for now",
    ],
    good: [
      "// the dialog is used to ask the user",
      "// the pipe is used to send frames; the id is used to read the file",
      "// a form not yet answered stays open",
      "// nothing yet to kill",
      "// retry: the server no longer accepts v1 tokens",
      "// restores the previously focused pane",
      "const previously = 1;",
    ],
  },
  {
    rule: "foreign-line-ref",
    path: "src/x.ts",
    bad: ["// LIB/main.js:353-438", "// see node_modules/pkg/dist/index.js:120"],
    good: [
      "// ABC: a three-letter tag is not a line reference",
      "// the library's main.js builds the options",
      "// listens on TCP:8080",
    ],
  },
  {
    rule: "test-name-citation",
    path: "test/unit/x.test.ts",
    bad: [
      'test("maps per research/03-options.md", () => {});',
      'test("matches LIB/main.js:353-438", () => {});',
      'test("the cache is no longer used", () => {});',
    ],
    good: [
      'test("an answer maps to its label", () => {});',
      'test("HTTP 404 and exit code -1 map to not-found", () => {});',
      'const s = "research/03-options.md is not a test name";',
    ],
  },
];

test("every rule the engine offers has a case", () => {
  const names = new Set(WITH_IDS.map((r) => r.name));
  assert.deepEqual(CASES.map((c) => c.rule).sort(), [...names].sort());
});

for (const c of CASES) {
  test(`${c.rule} fires on bad lines and not on good ones`, () => {
    for (const line of c.bad) assert.deepEqual(fired(c.path, line), [c.rule], line);
    for (const line of c.good) assert.deepEqual(fired(c.path, line), [], line);
  });
}

test("no id shape is built in: ordinary comments pass the library rules", () => {
  const ordinary = [
    "// row 0 is the header",
    "// Phase A of the two-phase commit",
    "// RFC 9110 §15.4: a 304 has no body",
    "// retry: the server no longer accepts v1 tokens",
    "// probe 3 times before giving up",
    "// column C3; B2: the second buffer",
  ];
  for (const line of ordinary) assert.deepEqual(fired("src/x.ts", line, BUILT_IN), [], line);
  assert.deepEqual(idRules(), []);
});

test("a rule with requires applies only to files whose text matches it", () => {
  const rule = { name: "x", test: /Date\.now\(\)/, requires: /\bnow:/, rule: "second clock" };
  assert.equal(checkFile("src/a.ts", "const t = Date.now();", [rule]).length, 0);
  assert.equal(checkFile("src/a.ts", "const f = (now: () => number) => Date.now();", [rule]).length, 1);
});

test("a multi-line block comment is checked on every line, and code after it is not", () => {
  const text = ["/**", " * Per research/03-options.md.", " */", "const x = 1; // fine"].join("\n");
  assert.deepEqual(
    checkFile("src/x.ts", text, BUILT_IN).map((h) => h.split(": ")[0]),
    ["src/x.ts:2"],
  );
  assert.equal(hits("src/x.ts", 'const url = "https://example.test/research/x";'), 0);
});

test("a quote or comment marker inside a regex literal does not hide or invent a comment", () => {
  assert.equal(hits("src/x.ts", 'const r = /"/; // B6'), 1);
  assert.equal(hits("src/x.ts", "const r = /'/g; // B6"), 1);
  assert.equal(hits("src/x.ts", 'const a = s.replace(/\\/*$/, "");\nconst k = "B6";'), 0);
  assert.equal(hits("src/x.ts", "const url = `\nhttp://a/research/x`;"), 0);
});

test("a regex literal after an arrow or return does not shift later comment lines", () => {
  const text = 'const f = (s) => /"/.test(s);\nconst g = 1;\n// B6';
  assert.deepEqual(
    checkFile("src/x.ts", text, WITH_IDS).map((h) => h.split(": ")[0]),
    ["src/x.ts:3"],
  );
  assert.equal(hits("src/x.ts", 'const f = (s) => /"/.test(s); // B6'), 1);
  assert.equal(hits("src/x.ts", 'function f(s) {\n  return /"/.test(s);\n}\n// B6'), 1);
});

test("a test name on the line after the call is attributed to its own line", () => {
  const text = 'test(\n  "S20: every entry has a title",\n  async () => {},\n);';
  assert.deepEqual(
    checkFile("test/unit/x.test.ts", text, WITH_IDS).map((h) => h.split(": ")[0]),
    ["test/unit/x.test.ts:2"],
  );
});

test("checkTree scopes rules by path, skips prefixes and ignores a missing root", () => {
  const scoped = {
    scan: ["src", "test", "missing"],
    skip: ["test/fixtures/"],
    ext: /\.ts$/,
    rules: [{ ...RULES.emptyCatch, applies: under("src") }, ...idRules(...ID_SHAPES)],
  };
  const root = mkdtempSync(join(tmpdir(), "craft-check-"));
  try {
    const write = (path: string, text: string) => {
      mkdirSync(dirname(join(root, path)), { recursive: true });
      writeFileSync(join(root, path), text);
    };
    write("test/unit/a.test.ts", "// B6\n");
    write("test/fixtures/c.test.ts", 'test("S1: fixture", () => {});\n');
    write("test/unit/d.test.ts", 'test("S1: scanned", () => {});\n');
    write("src/e.ts", "try { f(); } catch {}\n");
    write("test/unit/f.test.ts", "try { f(); } catch {}\n");
    write("src/g.md", "// B6\n");
    assert.deepEqual(
      checkTree(root, scoped)
        .map((hit) => hit.split(":")[0])
        .sort(),
      ["src/e.ts", "test/unit/a.test.ts", "test/unit/d.test.ts"],
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

// The only test that reads the repo's config: it holds whatever rules the repo enables there
test("the tree is clean under the repo's own config", () => {
  assert.deepEqual(checkTree(fileURLToPath(new URL("..", import.meta.url)), config), []);
});
