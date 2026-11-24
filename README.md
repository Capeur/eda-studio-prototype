# EDA Studio prototype

Prototype of the automated EDA lab loop on Mistral Studio: one deployed
orchestrator agent with two subagents sharing a Mistral sandbox:

- **eda-orchestrator** — routes David's one-word commands (`probe`, `build`, `verify`).
- **eda-builder** — clones the lab site repo, does one task, runs gates to 0/0,
  commits explicit paths, pushes `pending/<task>`.
- **eda-verifier** — independent: re-runs gates on the pending branch, regenerates
  golden `--json`, checks file sets, returns a strict `VERDICT: PASS | FAIL`.

Nothing ever pushes to `main`; David's rules carry over (0 errors / 0 warnings,
explicit paths, teacher repo/clone never touched, verdict before promotion).

## Phase 1: the probe

Run `bash scripts/probe.sh` in the sandbox (via `agents chat eda-orchestrator -m "probe"`).
It answers the five open questions:

1. Toolchain: Python 3.12, git, node, ffmpeg availability.
2. Network egress to pypi.org / api.github.com / the edge-tts endpoint.
3. A real one-sentence edge-tts voice build with the lab voices (en-US-Andrew, -4%).
4. `git clone` + commit + push of `pending/probe-<ts>` driven only by the
   sandbox's GitHub credential binding (no token value in the sandbox).
5. Whether a browser can exist (Playwright + chromium) — optional; if it fails,
   browser suites stay laptop gates, which is fine.

## One-time setup (David)

1. Studio: **Connectors** — connect GitHub (the sandbox binding uses it).
2. Studio: **Settings → Secrets** — create workspace secret `eda-github-pat`:
   a fine-grained PAT, release-2 scope, read/write **Contents only**, restricted
   to the Capeur site repos. This is the fallback if probe 4 fails; never paste
   it into chat, only into the Secrets page.
3. Admin console: your account needs the **Mistral Cloud User** (`cloud_user`)
   workspace role for MistralSandbox.
4. Create a Mistral API key, put it in `.env` as `MISTRAL_API_KEY`.

## Deploy

```bash
git clone https://github.com/Capeur/eda-studio-prototype.git && cd eda-studio-prototype
uv sync
uv run --env-file .env agents deploy
uv run --env-file .env agents chat eda-orchestrator -m "probe"
```

## Phase 2 (after the probe passes)

- Move builder/verifier to their own repos' tasks, wire a GitHub webhook trigger
  (`pending/*` push event starts a verifier session), and split the verifier's
  sandbox from the builder's.
