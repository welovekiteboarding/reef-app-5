# Linear Setup For reef-app-5

## Team

- team name: `ReefApp5`
- team key: `RA5`
- GitHub repo: `welovekiteboarding/reef-app-5`

## Workflow States

- `Todo`
- `In Progress`
- `Human Review`
- `Rework`
- `Merging`
- `Done`

## Environment Checklist

- set `LINEAR_API_KEY`
- confirm GitHub auth for `gh`
- confirm Codex is installed and available on the path

## Create The First Proof Issue

Create the first proof issue in Linear with:

- state: `Todo`
- title: `Bootstrap the first Linear to Codex to PR loop`
- description: `Create a small change in the repo, leave it ready for review, and prove the loop.`

## Manual Notes

- `mix symphony.setup` will create the first proof issue through the Linear API when the team already exists
- if the team is missing, setup will try the configured browser fallback runner before retrying
- if no browser fallback runner is configured, setup records `linear_browser_fallback_unavailable` in `config/symphony_setup.state.json`
- GitHub repo creation can be automated by `mix symphony.scaffold ... --github`
- run one queue cycle with `mix symphony.run --once`
- run the foreground queue with `mix symphony.run`
