#!/usr/bin/env bash
# Public-source replay of the proposed presentation boundary; synthetic only.
set -euo pipefail
bundle=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
python3 - "$stage" <<'PY'
import hashlib
import io
import pathlib
import sys
import tarfile
import urllib.request

url = "https://files.pythonhosted.org/packages/ae/9f/d77a1d1076075c80ee638b4c355725be52cfde05becab09cb38d36234352/signin_window-0.4.4.tar.gz"
with urllib.request.urlopen(url) as response:
    data = response.read()
expected = "3a33210007eafbd8accacc55b6f75b43e06f6909fe40bc282ef6dcd054322b59"
if hashlib.sha256(data).hexdigest() != expected:
    raise SystemExit("library source checksum mismatch")
with tarfile.open(fileobj=io.BytesIO(data)) as archive:
    archive.extractall(pathlib.Path(sys.argv[1]), filter="data")
PY
library="$stage/signin_window-0.4.4"
git -C "$library" apply --check "$bundle/library-prototype.patch"
git -C "$library" apply "$bundle/library-prototype.patch"
upstream="$stage/linkedin-mcp-server"
git init -q "$upstream"
git -C "$upstream" fetch -q --depth=2 https://github.com/stickerdaniel/linkedin-mcp-server.git \
  a9436662bfb2b3a432138f28255a84af0bc9ff7b
git -C "$upstream" checkout -q --detach FETCH_HEAD
git -C "$upstream" apply --check "$bundle/01-login-presentation-hooks.patch"
git -C "$upstream" apply "$bundle/01-login-presentation-hooks.patch"
uv sync --project "$upstream" --locked
python="$upstream/.venv/bin/python"
uv pip install --python "$python" "$library" playwright httpx uvicorn
(
  cd "$upstream"
  "$python" -m ruff check .
  "$python" -m ruff format --check .
  .venv/bin/ty check
  "$python" scripts/check_policy_traces.py --check
  "$python" scripts/generate_linkedin_architecture.py --check
  "$python" -m pytest tests/test_login_hooks.py tests/test_setup.py tests/test_login_viewer.py \
    tests/test_profile_lease.py tests/test_profile_lease_integration.py tests/test_browser_launch.py -q
)
(cd "$library" && "$python" -m pytest tests/test_child.py tests/test_service.py -q)
if [[ ${VERIFY_MUTATIONS:-0} == 1 ]]; then
  "$python" "$bundle/qualify_mutations.py" "$upstream"
fi
if [[ -z ${NOVNC_DIR:-} ]]; then
  curl --fail --silent --show-error --location \
    https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz -o "$stage/novnc.tar.gz"
  printf '%s  %s\n' 5066103959ef4e9b10f37e5a148627360dd8414e4cf8a7db92bdbd022e728aaa \
    "$stage/novnc.tar.gz" | sha256sum --check --status
  NOVNC_DIR="$stage/novnc"
  mkdir "$NOVNC_DIR"
  tar -xzf "$stage/novnc.tar.gz" -C "$NOVNC_DIR" --strip-components=1
fi
if [[ -z ${LINKEDIN_TEST_CHROME:-} ]]; then
  export PLAYWRIGHT_BROWSERS_PATH="$stage/browsers"
  PLAYWRIGHT_SKIP_BROWSER_GC=1 "$python" -m patchright install chromium
  LINKEDIN_TEST_CHROME=$("$python" -c \
    'from patchright.sync_api import sync_playwright; p = sync_playwright().start(); print(p.chromium.executable_path); p.stop()')
fi
export LINKEDIN_TEST_CHROME
SIGNIN_XVFB=${SIGNIN_XVFB:-Xvfb} SIGNIN_X11VNC=${SIGNIN_X11VNC:-x11vnc} \
  NOVNC_DIR="$NOVNC_DIR" \
  "$python" -m pytest "$library/examples/linkedin/test_acceptance.py" -v
