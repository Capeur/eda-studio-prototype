#!/usr/bin/env bash
# Sandbox probe: the four unknowns that decide if EDA lab work can run in Studio.
set -u
TS=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p probe-results
OUT="probe-results/$TS.md"
exec > >(tee -a "$OUT") 2>&1

echo "# Sandbox probe results ($TS)"

echo
echo "## 1. Python / toolchain"
python3 --version 2>&1
git --version 2>&1
node --version 2>&1 || echo "node: NOT INSTALLED"
ffmpeg -version 2>&1 | head -1 || echo "ffmpeg: NOT INSTALLED"

echo
echo "## 2. Network egress"
curl -sS -o /dev/null -w "pypi.org HTTP %{http_code}\n" https://pypi.org/simple/ 2>&1 || echo "pypi.org: FAIL"
curl -sS -o /dev/null -w "api.github.com HTTP %{http_code}\n" https://api.github.com 2>&1 || echo "api.github.com: FAIL"
curl -sS -o /dev/null -w "speech.platform.bing.com HTTP %{http_code}\n" https://speech.platform.bing.com 2>&1 || echo "edge-tts endpoint: FAIL"

echo
echo "## 3. edge-tts voice build"
python3 -m pip install --user --quiet --disable-pip-version-check edge-tts 2>&1
python3 -m edge_tts --voice en-US-AndrewMultilingualNeural --rate=-4% \
  --write-media "probe-results/voice-$TS.mp3" \
  "This is a voice build probe from the Studio sandbox." \
  && echo "edge-tts OK: $(wc -c < probe-results/voice-$TS.mp3) bytes" \
  || echo "edge-tts: FAIL"

echo
echo "## 4. git push on a pending branch"
rm -rf /tmp/probe-clone
if GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://github.com/Capeur/eda-studio-prototype.git /tmp/probe-clone 2>&1; then
  cp "$OUT" /tmp/probe-clone/ 2>/dev/null || cp "probe-results/$TS.md" /tmp/probe-clone/probe-results.md
  cd /tmp/probe-clone || exit 1
  git config user.name "eda-studio-probe"
  git config user.email "probe@localhost"
  git checkout -b "pending/probe-$TS"
  git add -A
  git commit -q -m "Sandbox probe $TS" 2>&1
  if GIT_TERMINAL_PROMPT=0 git push origin "HEAD:refs/heads/pending/probe-$TS" 2>&1; then
    echo "git push OK: probe results pushed to pending/probe-$TS"
  else
    echo "git push: FAIL (connector credential did not authenticate git; PAT fallback needed)"
  fi
else
  echo "git clone over HTTPS: FAIL (no credential reached git)"
fi

echo
echo "## 5. Browser availability (informational, last)"
timeout 300 bash -c '
  python3 -m pip install --user --quiet --disable-pip-version-check playwright 2>&1
  python3 -m playwright install chromium --with-deps 2>&1 | tail -2
' 2>&1 || echo "playwright: not available in this sandbox (browser suites stay laptop gates)"
