"""EDA Studio prototype: builder + verifier subagents under one orchestrator.

Phase 1 (this file): the orchestrator plus the two subagent roles, sharing a
Mistral-managed sandbox with open egress and a GitHub credential binding, so
the sandbox never holds a token value itself.

Deploy (from a clone of this repo, with MISTRAL_API_KEY in .env):
    uv sync
    uv run --env-file .env agents deploy

Start a probe session:
    uv run --env-file .env agents chat eda-orchestrator -m "probe"
"""

from mistralai import agents

REPO = "Capeur/eda-studio-prototype"

environment = agents.MistralSandbox(
    network=agents.Network.all(),
    header_bindings=(agents.GitHubBinding(repos=(REPO,)),),
)

builder = agents.Subagent(
    name="eda-builder",
    description=(
        "Builds one lab-site task in the sandbox: clone the repo, do the work, "
        "run gates, make an explicit-path commit, push a pending branch."
    ),
    instructions=(
        "You are the builder for David's EDA lab site repos. Execute exactly the task you are "
        "given, nothing more. Steps: clone the named GitHub repo over HTTPS (shallow), do the "
        "work exactly as specified, run every named gate to 0 errors / 0 warnings, commit only "
        "the explicit paths you were given, and push to refs/heads/pending/<task>. "
        "Never push to or touch main, never touch teacher repos, never hand-edit audio or "
        "timing files (rerun the voice build instead). End with a report: files touched, gate "
        "counts, every numeric claim and its source, deviations if any, the commit SHA."
    ),
)

verifier = agents.Subagent(
    name="eda-verifier",
    description=(
        "Independently verifies a pending branch: re-runs gates, regenerates golden outputs, "
        "checks the file set, and returns a strict PASS/FAIL verdict."
    ),
    instructions=(
        "You are an independent verifier: you did NOT build the work you are given, and you "
        "must not soften a verdict. Steps: clone the named repo at the given pending branch "
        "with --depth 1, re-run every non-browser gate, regenerate golden --json outputs and "
        "compare byte-for-byte where a canonical copy exists, compare the commit's file set to "
        "the expected explicit-path list (nothing missing, nothing extra, no MP4), and check "
        "the structural stamps named in the task. Browser suites are David's laptop gates: "
        "list them explicitly as 'not run (laptop gate)'. End with 'VERDICT: PASS' or "
        "'VERDICT: FAIL' plus evidence per check."
    ),
)

agent = agents.Agent(
    model="mistral-large-4",
    name="eda-orchestrator",
    instructions=(
        "You orchestrate David's EDA lab upgrade loop. David opens each session with exactly "
        "one command word: 'probe', 'build <task>', or 'verify <repo>/<branch>'.\n"
        "- 'probe': run scripts/probe.sh in your sandbox (bash scripts/probe.sh) and report each "
        "of the five probes honestly: toolchain, egress, edge-tts voice build, git push of a "
        "pending branch, browser availability. Quote the script's output for each. Do not "
        "summarize away a failure.\n"
        "- 'build': delegate to the eda-builder subagent with a fully self-contained task "
        "(repo, task, gate commands, explicit path list, pending branch name, voices and "
        "rates), then relay its report verbatim.\n"
        "- 'verify': delegate to the eda-verifier subagent and relay its verdict verbatim.\n"
        "Never invent tasks, never modify main, never touch teacher repos. Gates are "
        "0 errors / 0 warnings, no exceptions."
    ),
    environment=environment,
    subagents=[builder, verifier],
)
