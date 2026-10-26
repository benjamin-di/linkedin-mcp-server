# LinkedIn prototype evidence — 2026-10-26

This is synthetic Linux amd64 boundary evidence. No live LinkedIn account was
used. This public snapshot preserves the measurements made for the interface proposal.

## Versions and scope

- Upstream 4.28.0, base `0c5f14ba3efcd9ad1bbd3163b4f2b9e47cda7b17`.
- Prepared local hook commit `b56adc2`; exported as the patch beside this file.
- Library: checksum-pinned published signin-window 0.4.4 source plus the supplied development overlay.
- Python 3.13.17, Patchright 1.63.0, Chromium revision 1243
  (`Google Chrome for Testing 153.0.8010.12`), Playwright 1.64.1 for the test client.
- noVNC 1.6.0, release SHA-256
  `5066103959ef4e9b10f37e5a148627360dd8414e4cf8a7db92bdbd022e728aaa`.
- Xvfb, x11vnc and Openbox. The adapter borrows the display rather than creating
  or killing upstream's display, and does not change browser launch options.

## Results

The measurements below were originally captured on upstream base `0c5f14b`.
The independent public-source replay was subsequently repeated on
`a9436662bfb2b3a432138f28255a84af0bc9ff7b`, with the upstream lock's FastMCP
4.1.3, and passed 162 focused upstream tests, 41 library regression tests,
the six-test control plus five behavioral mutations, and four real-browser cases
in 79.33 seconds. It uses only public sources; see `REPLAY-RESULTS.txt` and
`verify.sh`. The hook patch applies unchanged to both upstream bases. The broader
suite's 91 failures and baseline comparison below are measurements of the original
base, not a full-suite claim for the newer dependency set.

| Check | Result |
|---|---|
| Library `make check` | 243 passed, 3 optional-browser skips; lint/format passed |
| Clean-checkout upstream replay | 162 focused tests passed; ruff, format, ty, architecture and policy traces passed |
| New upstream hook tests | 6 passed; all qualified by deliberately failing behavioral mutations |
| Broader login/session/launch checks | 258 passed, 1 Windows-only skip, 2 container-detection failures reproduced on original upstream |
| Real Chromium/noVNC acceptance from replay | 4 passed in 79.29 seconds |
| Broader upstream suite, four workers | 8,229 passed, 91 failed, 90 skipped, 88% coverage; not a green full gate |
| All 91 failure selectors on pinned original upstream | The same 91 failed in 23.68 seconds, using identical dependencies in a disposable baseline checkout |

The broader command was `pytest --cov -n 4 -m 'not browser_dom and not
browser_contract and not browser_identity and not differential_browser and not
image_build'`. Native/browser/image qualification outside the four adapter cases
was excluded. Unrelated broad-suite failures are not silently waived; current
upstream qualification is still required before a PR can be called ready.
All 91 failed selectors reproduced without the patch. They are recorded in
`baseline-failures.txt`; from a checkout of the pinned original base, load those
lines into a shell array with `mapfile -t cases < /path/to/baseline-failures.txt`
and run `uv run pytest -n 4 "${cases[@]}"` against the same locked dependencies.

The four real-browser cases demonstrate:

1. Authenticated link creation, page reload without a second browser, remote
   keyboard input, lease contention while waiting, existing cookie/source-state
   formats, confirmed completion and display survival.
2. Closing the page during acknowledged saving leaves publication running.
3. Cancelling a replacement login restores the previous generation and exact
   cookie bytes and makes the profile available to a new lease holder.
4. Failed cookie export never reports connected or publishes a source generation;
   the lease is released after cleanup.

Library tests additionally reject session payloads or failed records in retained
mode, require successful process exit, abort on a missing saving acknowledgement,
wait for a child's cancellation restoration, and reject stream input/output
after saving even before the periodic viewer watcher runs.

## Mutation qualification

`VERIFY_MUTATIONS=1 bash verify.sh` uses scratch
copies. The unmodified six-test control passed; each of these changes caused its
targeted behavioral assertion to fail:

- Remove the saving notification: ordering and observer-failure restoration.
- Always report confirmed closure: unconfirmed teardown test.
- Treat failed cookie export as success: failed-export/restoration test.
- Propagate a closed observer's exception: completed-save preservation test.
- Accept an injected viewer without explicit viewer mode: opt-in test.

No mutations were retained in either checkout. The replay also reproduced the two
container-detection failures with the pinned original `setup.py`.

## Reproduction and remaining qualification

Run `NOVNC_DIR=/path/to/noVNC-1.6.0 VERIFY_MUTATIONS=1 bash
verify.sh`. The script checks patch application,
installs the upstream lock in a temporary checkout and uses temporary synthetic
profiles. It supports fixture binary overrides documented in the example.

The original Docker viewer remains the default. The library adds value when a
host already needs authenticated expiring links, page reload recovery and saves
that complete independently of the page. This prototype does not establish live
authentication success, production proxy routing, fingerprint equivalence,
mobile/password-manager acceptance, browser confinement or cross-platform
behavior. A dedicated display remains necessary. Paste and confinement proposals
#1385/#1403 are separate work.
