/**
 * init-craft Pi adapter: lets Pi read a repo's Claude-style layout.
 *  - resources_discover: adds `<repo>/.claude/skills` as a skill path (repo = git toplevel of cwd).
 *  - before_agent_start: adds every `CLAUDE.local.md` from cwd up to the repo root (outermost first)
 *    to the context files, expanding `@path` imports (relative to the file, `~/` allowed, max depth 4,
 *    skipping code spans and fences).
 * scripts/machine.sh links this file into each Pi profile's `extensions/` (never copy it).
 */
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX_DEPTH = 4;

function repoRoot(cwd: string): string {
	try {
		return execFileSync("git", ["rev-parse", "--show-toplevel"], { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim() || cwd;
	} catch {
		return cwd;
	}
}

const sameFile = (a: string, b: string) => {
	if (a === b) return true;
	try { return realpathSync(a) === realpathSync(b); } catch { return false; }
};

const isFile = (p: string) => { try { return statSync(p).isFile(); } catch { return false; } };

function resolveImport(token: string, baseDir: string): string | undefined {
	let p = token.slice(1).replace(/[),.;:]+$/, "");
	if (!p) return;
	if (p.startsWith("~/")) p = join(homedir(), p.slice(2));
	const abs = resolve(baseDir, p);
	return isFile(abs) ? abs : undefined;
}

/** Expand `@path` imports outside fenced blocks and inline code spans. */
function expand(file: string, depth = 0, seen = new Set<string>()): string {
	seen.add(file);
	const out: string[] = [];
	let fence: string | null = null;
	for (const line of readFileSync(file, "utf8").split("\n")) {
		const f = line.match(/^\s*(`{3,}|~{3,})/);
		if (f) { if (!fence) fence = f[1][0]; else if (f[1][0] === fence) fence = null; out.push(line); continue; }
		if (fence || depth >= MAX_DEPTH) { out.push(line); continue; }
		out.push(line);
		const noCode = line.replace(/(`+)[\s\S]*?\1/g, " "); // drop inline code spans
		for (const tok of noCode.split(/\s+/)) {
			if (!tok.startsWith("@")) continue;
			const target = resolveImport(tok, dirname(file));
			if (!target || seen.has(target)) continue;
			out.push(`\n<!-- imported from ${tok} -->\n${expand(target, depth + 1, seen)}`);
		}
	}
	return out.join("\n");
}

export default function (pi: ExtensionAPI) {
	pi.on("resources_discover", (event) => {
		const dir = join(repoRoot(event.cwd), ".claude", "skills");
		return existsSync(dir) ? { skillPaths: [dir] } : undefined;
	});

	pi.on("before_agent_start", (event, ctx) => {
		let cwd: string, root: string;
		try {
			cwd = realpathSync(ctx.cwd); // macOS: /tmp -> /private/tmp, git returns the real path
			root = realpathSync(repoRoot(cwd));
		} catch {
			return;
		}
		const dirs: string[] = [];
		for (let d = cwd; ; d = dirname(d)) {
			dirs.unshift(d); // outermost first
			if (d === root || dirname(d) === d) break;
		}
		const files = event.systemPromptOptions.contextFiles;
		for (const d of dirs) {
			const p = join(d, "CLAUDE.local.md");
			if (!isFile(p) || files.some((f) => sameFile(f.path, p))) continue;
			files.push({ path: p, content: expand(p) });
		}
	});
}
