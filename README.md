# Clawkit

<div align="center">
  <img src="clawkit.jpeg" alt="Clawkit Brand" width="400"/>
</div>

Clawkit simplifies managing openclaw agents workspace using [sshkit](https://github.com/capistrano/sshkit). Useful to know when your agents memory have so many garbage context or when their `SOUL.md` suddenly changed 🤖.

[![preview](https://asciinema.org/a/788239.svg)](https://asciinema.org/a/788239)

## Prerequisites

- Ruby
- Bundler (`gem install bundler`)
- rsync (installed on remote hosts via `bin/bootstrap`)

## Setup

1. Clone the repository and install dependencies:

```sh
git clone git@github.com:firewalker06/clawkit.git
cd clawkit
bundle install
```

2. Create a `.env` file with your host(s):

```
HOSTS=10.0.0.1
```

Multiple hosts can be comma-separated: `HOSTS=10.0.0.1,10.0.0.2`

3. Copy the sample config and edit it:

```sh
cp config.yml.sample config.yml
```

Edit `config.yml` to configure your SSH user, remote path, directories and files:

```yaml
ssh_user: debian
remote_path: /home/debian/.openclaw

hosts:
  - 10.0.0.1 # Overridden by HOSTS in .env

directories:
  - name: my-agent
    source: openclaw/workspace-my-agent
    target: workspace

# Sync individual files:
# files:
#   - name: gateway-config
#     source: openclaw/config.json
#     target: config.json

# Or use wildcard to sync the whole remote_path:
# files: "*"
```

`directories:` entries map a local `source` directory (inside `openclaw/`) to a `target` directory under `remote_path` on the remote host. `files:` entries sync individual files. Setting `files: "*"` syncs the entire `remote_path`.

4. Create your workspace directories inside `openclaw/`:

```sh
mkdir -p openclaw/workspace-my-agent
```

The `openclaw/` directory is gitignored from the clawkit repo and managed as its own git repo for change detection. Place your agent files (identity, memory, skills, etc.) in each workspace directory.

## Commands

### `bin/bootstrap`

Installs rsync on all configured remote hosts. Run this once before using `bin/sync`.

```sh
bin/bootstrap
```

### `bin/sync`

Syncs directories and files between your local machine and the remote host using rsync. The command automatically stops the openclaw gateway before syncing and starts it again after.

```sh
bin/sync              # Sync all configured items
bin/sync my-agent     # Sync a specific item by name
```

For each item, `sync` downloads from the remote host, then uses git to detect what changed inside `openclaw/`. If changes are found, you're prompted with:
- **See changes**: Opens `openclaw/` in VS Code to review diffs
- **Restart**: Discards downloaded changes and re-downloads from remote
- **Upload**: Commits the changes and pushes them back to the remote host
- **Skip**: Discards the downloaded changes

The `openclaw/` directory is automatically initialized as a git repo on first run.

### `bin/console`

Opens an SSH session to a remote host.

```sh
bin/console           # Connect to the first configured host
bin/console 10.0.0.5  # Connect to a specific host
```
