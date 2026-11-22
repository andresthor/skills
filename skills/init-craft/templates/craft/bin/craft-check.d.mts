export type Language =
  | "js"
  | "go"
  | "rust"
  | "java"
  | "kotlin"
  | "swift"
  | "c"
  | "csharp"
  | "php"
  | "python"
  | "ruby"
  | "shell"
  | "toml"
  | "yaml"
  | "make"
  | "docker";
/** One entry per line of the file; `code` has no comments and every string emptied. */
export interface Source {
  path: string;
  lang: Language | null;
  lines: string[];
  code: string[];
  comments: string[];
  names: string[][];
}
export interface Rule {
  name: string;
  rule: string;
  /** Matched per line against `target`; a rule gives this or `find`. */
  test?: RegExp;
  /** Indexes into `Source.lines` of the lines that break the rule. */
  find?: (source: Source) => number[];
  target?: "comment" | "test-name";
  applies?: (path: string) => boolean;
  langs?: Language[];
  requires?: RegExp;
}
export interface Config {
  scan: string[];
  skip?: string[];
  /** Tested against the file name; without it, every file with a known language is checked. */
  ext?: RegExp;
  rules: Rule[];
}
export const RULES: Record<
  | "emptyCatch"
  | "boundaryCast"
  | "emptyHandler"
  | "docCitation"
  | "buildHistory"
  | "foreignLineRef"
  | "testNameCitation",
  Rule
>;
export const LANGUAGES: Record<Language, { ext?: string; names?: string }>;
export function under(...dirs: string[]): (path: string) => boolean;
export function idToken(token: string): RegExp;
export function idRules(...shapes: RegExp[]): Rule[];
export function languageOf(path: string, text?: string): Language | null;
export function checkFile(path: string, text: string, rules?: Rule[]): string[];
export function checkTree(root: string, config: Config): string[];
