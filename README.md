# skills

Skills that I find useful *at the moment* and use regularly.

A constant work in progress.

## Installing

### Copy or symlink

Copy or symlink a single skill into an agent's skills directory:

```sh
cp -r "$PWD/skills/<name>" ~/.claude/skills/<name>
```

```sh
ln -s "$PWD/skills/<name>" ~/.claude/skills/<name>
```

### As a plugin

In Claude Code, this installs everything under `skills/` and picks up new ones when you update:

```
/plugin marketplace add andresthor/skills
/plugin install ats@andresthor
```

Skills then appear under the `ats:` prefix, so `orchestrate` is invoked as `ats:orchestrate`.

## License

MIT — see [LICENSE](LICENSE).
