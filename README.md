# skills

Skills that I find useful *at the moment* and use regularly.

A constant work in progress.

## Installing

As a plugin — in Claude Code, this installs everything under `skills/` and picks up new ones when you update:

```
/plugin marketplace add andresthor/skills
/plugin install ats@andresthor
```

Skills then appear under the `ats:` prefix, so `orchestrate` is invoked as `ats:orchestrate`.

Or symlink a single skill into an agent's skills directory:

```sh
ln -s "$PWD/skills/<name>" ~/.claude/skills/<name>
```

## License

MIT — see [LICENSE](LICENSE).
