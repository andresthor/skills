import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import config from "../bin/craft-check.config.mjs";
import { checkFile, checkTree, idRules, idToken, languageOf, RULES, under } from "../bin/craft-check.mjs";

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
// Hits as "line rule", for sources where the line a hit lands on is the point
const where = (path: string, lines: string[], rules = WITH_IDS) =>
  checkFile(path, lines.join("\n"), rules).map((hit) => hit.replace(/^[^:]+:(\d+): \[([\w-]+)\].*$/, "$1 $2"));

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
    rule: "empty-handler",
    path: "src/x.py",
    bad: [
      "except OSError: pass",
      "try:\n    f()\nexcept OSError:\n    pass",
      "except:\n    ...",
      "    except (KeyError, ValueError) as e:\n\n        pass\n    return 1",
    ],
    good: [
      "except OSError:\n    pass  # the file is already gone",
      "except OSError:  # the file is already gone\n    pass",
      "except OSError:\n    # the file is already gone\n    pass",
      "except OSError as e:\n    log(e)",
      "except OSError:\n    pass\n    cleanup()",
      "except OSError: return None",
      's = "except OSError: pass"',
      'd = """\nexcept OSError:\n    pass\n"""',
    ],
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
    bad: [
      "// LIB/main.js:353-438",
      "// see node_modules/pkg/dist/index.js:120",
      "// see site-packages/pkg/core.py:120",
      "// vendor/lib/conn.go:88 closes it",
      "// ~/.cargo/registry/src/pkg-1.2.0/src/lib.rs:12",
      "// pkg/mod/example.test/lib@v1.2.0/conn.go:88",
    ],
    good: [
      "// ABC: a three-letter tag is not a line reference",
      "// the library's main.js builds the options",
      "// listens on TCP:8080",
      "// dials vendor/host:8080",
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

test("empty-handler fires on an empty Go error check and not on a handled or explained one", () => {
  const bad = ["if err != nil {\n}", "if err := f(); err != nil {}", "\t_ = err"];
  const good = [
    "if err != nil {\n\t// the peer is gone; the caller retries\n}",
    "if err != nil {\n\treturn err\n}",
    "if err != nil { /* the peer is gone */ }",
    "_ = err // Close reports it",
    's := "if err != nil {}"',
    "x := `\nif err != nil {}\n_ = err\n`",
    "if err == nil {}",
    "_ = value",
  ];
  for (const text of bad) assert.deepEqual(fired("x.go", text), ["empty-handler"], text);
  for (const text of good) assert.deepEqual(fired("x.go", text), [], text);
});

test("a rule holds only in the languages it declares", () => {
  for (const path of ["src/x.py", "x.go", "src/lib.rs", "scripts/x.sh"]) {
    assert.deepEqual(fired(path, "try { f(); } catch {}"), [], path);
    assert.deepEqual(fired(path, "const m = JSON.parse(s) as Message;"), [], path);
  }
  for (const path of ["src/x.ts", "src/x.rb", "src/lib.rs"]) {
    assert.deepEqual(fired(path, "except OSError: pass\nif err != nil {}\n_ = err"), [], path);
  }
  const rule = { name: "x", test: /print\(/, langs: ["python" as const], rule: "stray print" };
  assert.equal(checkFile("src/a.py", "print(1)", [rule]).length, 1);
  assert.equal(checkFile("src/a.rb", "print(1)", [rule]).length, 0);
  assert.equal(checkFile("src/a.py", "print(1)", [{ ...rule, applies: under("lib") }]).length, 0);
});

test("a file's language comes from its extension, its name or its #! line", () => {
  const exts = "js ts jsx tsx mjs cjs go rs java kt swift c h cpp cs php py rb sh bash zsh toml yaml yml";
  for (const ext of exts.split(" ")) assert.notEqual(languageOf(`src/a.${ext}`), null, ext);
  assert.equal(languageOf("Makefile"), "make");
  assert.equal(languageOf("docker/Dockerfile"), "docker");
  assert.equal(languageOf("bin/tool", "#!/bin/sh\n"), "shell");
  assert.equal(languageOf("bin/tool", "#!/usr/bin/env bash\n"), "shell");
  assert.equal(languageOf("bin/tool", "#!/usr/bin/env python3\n"), "python");
  assert.equal(languageOf("bin/tool", "#!/usr/bin/ruby -w\n"), "ruby");
  assert.equal(languageOf("bin/tool", "# plain text\n"), null);
  assert.equal(languageOf("docs/a.md"), null);
  assert.deepEqual(where("bin/tool", ["#!/usr/bin/env bash", "# see plan.md"]), ["2 doc-citation"]);
  assert.deepEqual(where("bin/tool", ["#!/usr/bin/env python3", "x = 1  # see plan.md"]), ["2 doc-citation"]);
});

test("a file in no known language has no comments, and only rules without langs read its lines", () => {
  const clock = { name: "x", test: /Date\.now\(\)/, rule: "second clock" };
  const source = ["// B6", "# see plan.md", "Date.now()", "catch {}"];
  assert.deepEqual(where("notes.txt", source, [...WITH_IDS, clock]), ["3 x"]);
});

test("Python: only # outside strings opens a comment, and a docstring is not one", () => {
  const source = [
    '"""Module docstring: see plan.md step 3."""',
    'x = "# not a comment, plan.md"',
    "y = '''",
    "# plan.md inside a triple-quoted string",
    "'''",
    "def f():",
    '    """Docstring citing research/01.md."""',
    "    return 1  # plan.md step 3",
    "z = 'it' 's'  # B6",
    's = "a\\"b # plan.md"',
    "t = r'\\' # plan.md'",
    'u = f"{x}"  # previously this threw',
  ];
  assert.deepEqual(where("src/pkg/mod.py", source), ["8 doc-citation", "9 step-id", "12 build-history"]);
});

test("shell: $#, ${#x}, quotes, an escaped # and a here-document are not comments", () => {
  const source = [
    "#!/bin/sh",
    "echo $# ${#x} a#b  # B6",
    "echo 'it # plan.md' \"x # plan.md\"",
    "cat <<EOF",
    "# plan.md in a here-document, and it's unbalanced",
    "EOF",
    "echo \\# plan.md \\' \\\"",
    "# see plan.md",
    "x='spans",
    "# plan.md'",
    "y=$'it\\'s' ;# research/01.md",
    "n=$(( 1 << 2 )) # B4",
  ];
  assert.deepEqual(where("scripts/x.sh", source), [
    "2 step-id",
    "8 doc-citation",
    "11 doc-citation",
    "12 step-id",
  ]);
});

test("Ruby: interpolation, =begin blocks and here-documents are read as Ruby reads them", () => {
  const source = [
    'x = "a #{h["k"]} # plan.md"  # B6',
    "y = 'it # plan.md'",
    "=begin",
    "see plan.md",
    "=end",
    "s = <<~TEXT",
    "  # plan.md, and it's unbalanced",
    "TEXT",
    "list << item  # research/01.md",
  ];
  assert.deepEqual(where("lib/x.rb", source), ["1 step-id", "4 doc-citation", "9 doc-citation"]);
});

test("TOML, YAML and a Makefile: # opens a comment outside quotes", () => {
  const toml = ['k = "# plan.md"  # B6', 'm = """', "# plan.md", '"""', "n = 1# see plan.md"];
  assert.deepEqual(where("a.toml", toml), ["1 step-id", "5 doc-citation"]);
  const yaml = ["url: http://x/a#plan.md", "k: 'a # plan.md'", "v: 1 # see plan.md"];
  assert.deepEqual(where("a.yml", yaml), ["3 doc-citation"]);
  assert.deepEqual(where("Makefile", ["all: # see plan.md", "\t@echo $#"]), ["1 doc-citation"]);
});

test("Go: a raw string hides comment markers, and a rune holding a quote opens no string", () => {
  const source = [
    "package main",
    "// see plan.md",
    "var q = `",
    "// plan.md in a raw string \\",
    "`",
    "var r = '\"' // B6",
    'var u = "http://x/research/y" // fine',
    'var w = `a` + "`" // research/01.md',
    "var d = a / b // previously this threw",
  ];
  assert.deepEqual(where("main.go", source), [
    "2 doc-citation",
    "6 step-id",
    "8 doc-citation",
    "9 build-history",
  ]);
});

test("Rust: lifetimes, char literals, raw strings and nested block comments", () => {
  const source = [
    "fn f<'a>(x: &'a str) -> &'a str { x } // B6",
    "let c = '#'; let d = '\"'; let e = '\\''; let g = '\\u{1F600}'; // plan.md",
    'let r = r#"// plan.md "quoted" # "#; // fine',
    "/* outer /* inner */ still a comment: plan.md */",
    'let s = "/* "; let t = 1; // research/02.md',
    'let m = "line one',
    '// plan.md inside a multi-line string";',
    'let b = br##"# plan.md "# "##; let raw = r#type;',
    "let x: &'static str = \"// plan.md\";",
    "let y = 'x'; 'outer: loop { break 'outer; } // B4",
  ];
  assert.deepEqual(where("src/lib.rs", source), [
    "1 step-id",
    "2 doc-citation",
    "4 doc-citation",
    "5 doc-citation",
    "10 step-id",
  ]);
});

test("block comments nest only where the language nests them", () => {
  const nested = ["/* a /* b */ still: plan.md */", "// B6"];
  assert.deepEqual(where("src/A.java", nested), ["2 step-id"]);
  assert.deepEqual(where("src/a.kt", nested), ["1 doc-citation", "2 step-id"]);
  const php = ["#[Route('/plan.md')]", "# see plan.md", "$a = '# plan.md'; // B6"];
  assert.deepEqual(where("src/a.php", php), ["2 doc-citation", "3 step-id"]);
});

test("JS regex literals are read only in JS: a slash elsewhere is a division or a path", () => {
  assert.deepEqual(where("src/x.ts", ['const r = /"/; // B6', "const k = 1;"]), ["1 step-id"]);
  assert.deepEqual(where("x.go", ['x := a /b; s := "/"; // B6', "// B4"]), ["1 step-id", "2 step-id"]);
  assert.deepEqual(where("src/x.py", ["x = (a /b) # B6", "y = '/' # B4"]), ["1 step-id", "2 step-id"]);
  assert.deepEqual(where("bin/tool.mjs", ["#!/usr/bin/env node", "// B6"]), ["2 step-id"]);
});

test("test names are found in each ecosystem's own shape", () => {
  const cases: [string, string[], string[]][] = [
    ["t/test_x.py", ["def test_S54_answer_maps():", "    async def test_row_9a_is_held(self):"], ["1 step-id", "2 step-id"]],
    ["t/test_x.py", ["def test_handles_C1_control_codes():", "def helper_S54():", 's = "def test_S54_x():"'], []],
    ["x_test.go", ["func TestS54AnswerMaps(t *testing.T) {", '\tt.Run("S1: subtest", f)'], ["1 step-id", "2 step-id"]],
    ["x_test.go", ['\tt.Run("matches LIB/main.go:353", f)'], ["1 test-name-citation"]],
    ["x_test.go", ["func TestAnswerMapsToLabel(t *testing.T) {", 'cmd.Run("S1: no test")', "func helperS54() {}"], []],
    ["src/lib.rs", ["#[test]", "fn row_9a_is_held() {}"], ["2 step-id"]],
    ["src/lib.rs", ["#[tokio::test]", '#[should_panic(expected = "x")]', "", "async fn scenario_4_holds() {}"], ["4 step-id"]],
    ["src/lib.rs", ["fn row_9a() {}", "#[cfg(test)]", "fn row_9b() {}", "#[test]", "fn it_maps() {}", "fn row_9c() {}"], []],
    ["spec/x_spec.rb", ['it "S1: maps" do', 'RSpec.describe "invariant 9" do', "  context 'row 9a' do"], ["1 step-id", "2 step-id", "3 step-id"]],
    ["spec/x_spec.rb", ['test "maps per research/03-options.md" do'], ["1 test-name-citation"]],
    ["spec/x_spec.rb", ['submit "S1: no test"', 'it "maps an answer to its label" do', 'form.it "S1: x"'], []],
  ];
  for (const [path, source, expected] of cases) assert.deepEqual(where(path, source), expected, source.join(" | "));
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

test("without ext, checkTree checks the files whose language it knows and enters no dot-directory", () => {
  const root = mkdtempSync(join(tmpdir(), "craft-check-"));
  try {
    const write = (path: string, text: string) => {
      mkdirSync(dirname(join(root, path)), { recursive: true });
      writeFileSync(join(root, path), text);
    };
    write("main.go", "// B6\n");
    write("src/a.py", "# B6\n");
    write("src/b.rs", "// B6\n");
    write("src/notes.md", "# B6\n");
    write("bin/tool", "#!/bin/sh\n# B6\n");
    write("bin/blob", "# B6\n");
    write("src/node_modules/x.js", "// B6\n");
    write("src/__pycache__/x.py", "# B6\n");
    write(".git/x.go", "// B6\n");
    write("vendor/lib/x.go", "// B6\n");
    write(".hooks/pre-commit.sh", "# B6\n");
    const files = (scan: string[], skip: string[] = []) =>
      checkTree(root, { scan, skip, rules: idRules(...ID_SHAPES) })
        .map((hit) => hit.split(":")[0])
        .sort();
    assert.deepEqual(files(["."], ["vendor/"]), ["bin/tool", "main.go", "src/a.py", "src/b.rs"]);
    assert.deepEqual(files(["src", ".hooks", "absent"]), [".hooks/pre-commit.sh", "src/a.py", "src/b.rs"]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

// The only test that reads the repo's config: it holds whatever rules the repo enables there
test("the tree is clean under the repo's own config", () => {
  assert.deepEqual(checkTree(fileURLToPath(new URL("..", import.meta.url)), config), []);
});
