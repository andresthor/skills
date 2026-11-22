export interface Rule {
  name: string;
  test: RegExp;
  rule: string;
  target?: "comment" | "test-name";
  applies?: (path: string) => boolean;
  requires?: RegExp;
}
export interface Config {
  scan: string[];
  skip?: string[];
  ext: RegExp;
  rules: Rule[];
}
export const RULES: Record<
  | "emptyCatch"
  | "boundaryCast"
  | "docCitation"
  | "buildHistory"
  | "foreignLineRef"
  | "testNameCitation",
  Rule
>;
export function under(...dirs: string[]): (path: string) => boolean;
export function idToken(token: string): RegExp;
export function idRules(...shapes: RegExp[]): Rule[];
export function checkFile(path: string, text: string, rules?: Rule[]): string[];
export function checkTree(root: string, config: Config): string[];
