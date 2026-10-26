# Optional manual-login presentation: LinkedIn prototype

This evidence branch demonstrates two optional keywords on `interactive_login()`:
`observer` for structured progress/confirmed teardown and `viewer_factory` for a
hosted viewer. The upstream change adds no dependency on `signin-window`, no MCP
tool and no browser launch configuration change. It preserves the ordinary CLI
and Docker viewer when no hooks are passed.

Upstream retains browser/proxy configuration, Openbox, profile claims and leases,
rotation, manual-login detection, cookie export, source generation, restoration
and browser cleanup. The external library supplies authenticated expiring links,
reload recovery and a viewer on the existing dedicated X display. Cookies remain
in upstream's existing files. The child waits for the host to acknowledge control
revocation before saving; completion requires upstream success, confirmed browser
shutdown, the normal session files, a connected record and a successful exit.

The built-in viewer remains sufficient for ordinary local Docker login. These
hooks benefit applications that already provide their own authenticated front.

| File | Purpose |
|---|---|
| `01-login-presentation-hooks.patch` | One proposed upstream patch, including six behavioral tests and API docs |
| `library-prototype.patch` | Development overlay on the published signin-window 0.4.4 source: embedded viewing, reload/lifecycle support, acknowledged retained-child publication, regression tests and four synthetic acceptance cases |
| `verify.sh` | Independent replay using public sources and temporary profiles |
| `qualify_mutations.py` | Six-test control and five deliberately failing behavioral mutations |
| `VALIDATION.md` | Recorded measurements and qualification limits |
| `REPLAY-RESULTS.txt` | Independent replay results on the newer pinned upstream head |
| `baseline-failures.txt` | All 91 broader-suite failure selectors, reproduced on original upstream |

## Reproduce

Use Linux amd64, Python 3.13, uv, Git, Xvfb, x11vnc, Openbox and Chromium's system
libraries. A Debian trixie environment is suitable. For example, install the
display packages and browser dependencies in a disposable environment:

```sh
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git xvfb x11vnc openbox
uvx --from patchright==1.63.0 patchright install-deps chromium
```

From this directory:

```sh
VERIFY_MUTATIONS=1 bash verify.sh
```

The script fetches exact upstream base
`a9436662bfb2b3a432138f28255a84af0bc9ff7b` (4.28.0 plus the FastMCP dependency update), applies the hook patch,
installs its locked dependencies, and overlays the checksum-verified published
library source. It verifies noVNC 1.6.0 by its release checksum and installs the
matching Patchright browser into a private temporary cache with cache garbage
collection disabled. `NOVNC_DIR` may instead name an already verified noVNC 1.6.0
directory; `LINKEDIN_TEST_CHROME`, `SIGNIN_XVFB` and `SIGNIN_X11VNC` may override
the fixture binaries. No public or private library checkout is required.

All source and synthetic profiles are temporary and removed at exit. Nothing
contacts LinkedIn or changes a shared checkout. The acceptance fixtures fulfill
the sign-in/feed documents at the normal LinkedIn origin and abort other context
requests, while browser launch and upstream session mechanics remain real.

## Results and limits

The recorded source run passed 243 library tests, 162 focused upstream tests, all
five behavioral mutations, and four real Chromium/noVNC cases: reload and success
with lease contention, page closure during saving, cancellation restoring the
previous session, and export failure without success. The broader upstream run
reported 8,229 passed, 91 failed and 90 skipped; every failed selector also failed
on the pinned original upstream with identical dependencies. The full upstream
gate is not claimed green. This replay runs the relevant library regression
tests and focused upstream tests, rather than repeating that whole suite.

No real account, password, session, page capture or deployment detail is included.
This demonstrates the integration boundary, not live LinkedIn authentication,
production proxy routing, fingerprint equivalence, mobile behavior or browser
confinement. The display must be dedicated to login. Paste and confinement work
in upstream issues #1385/#1403 stays separate.

This supporting branch is evidence for interface discussion. It is not the
implementation PR; that patch will be submitted after maintainer agreement.
