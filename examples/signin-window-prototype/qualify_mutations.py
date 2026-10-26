"""Qualify the new upstream tests in disposable copies, without editing the checkout."""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

source = Path(sys.argv[1]).resolve()
mutations = [
    (
        "omit-saving",
        'observer(LoginProgress("saving"))',
        "pass",
        "test_progress_closes_only_after_browser_and_lease_cleanup or "
        "test_observer_failure_before_export_runs_normal_restore",
    ),
    (
        "claim-closed",
        'LoginProgress("closed", close_confirmed=state.close_confirmed)',
        'LoginProgress("closed", close_confirmed=True)',
        "test_unconfirmed_teardown_is_reported_without_releasing_the_profile",
    ),
    (
        "hide-export-failure",
        'failure = RuntimeError("cookie export failed")\n                return False',
        'failure = RuntimeError("cookie export failed")\n                return True',
        "test_failed_export_keeps_failure_and_restores_the_previous_session",
    ),
    (
        "propagate-closed-observer",
        "except Exception as exc:\n                # Observation",
        "except LookupError as exc:\n                # Observation",
        "test_post_cleanup_observer_failure_does_not_undo_a_saved_session",
    ),
    (
        "accept-implicit-viewer",
        "if viewer_factory is not None and not login_viewer:",
        "if False:",
        "test_injected_viewer_requires_explicit_viewer_mode",
    ),
]
with tempfile.TemporaryDirectory(prefix="linkedin-hook-mutations-") as stage:
    scratch = Path(stage) / "source"
    shutil.copytree(
        source,
        scratch,
        ignore=shutil.ignore_patterns(
            ".git", ".venv", "__pycache__", ".pytest_cache", ".coverage", ".ruff_cache"
        ),
    )
    target = scratch / "linkedin_mcp_server" / "setup.py"
    original = target.read_text()

    def run(selection=None):
        argv = [sys.executable, "-m", "pytest", "tests/test_login_hooks.py", "-q"]
        if selection:
            argv += ["-k", selection]
        return subprocess.run(
            argv,
            cwd=scratch,
            env={**os.environ, "PYTHONPATH": str(scratch)},
            capture_output=True,
            text=True,
        )

    control = run()
    if control.returncode:
        raise SystemExit(control.stdout + control.stderr)
    print("control: 6 passed", flush=True)
    for name, before, after, selection in mutations:
        assert original.count(before) == 1, name
        target.write_text(original.replace(before, after))
        result = run(selection)
        # Collection/import failures do not qualify a behavioral mutation.
        assert (
            result.returncode == 1
            and "FAILED tests/test_login_hooks.py::" in result.stdout
        ), (
            name,
            result.stdout,
            result.stderr,
        )
        print(f"{name}: detected by behavioral assertion", flush=True)
    target.write_text(original)

    # Reproduce the two host-specific failures with unmodified upstream setup.
    target.write_bytes(
        subprocess.check_output(
            [
                "git",
                "show",
                "0c5f14ba3efcd9ad1bbd3163b4f2b9e47cda7b17:linkedin_mcp_server/setup.py",
            ],
            cwd=source,
        )
    )
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "pytest",
            "tests/test_session_state.py::TestContainerDetection::test_a_systemd_container_marker_is_not_trusted_on_its_own",
            "tests/test_session_state.py::TestContainerDetection::test_the_whole_decision_survives_a_host_running_containers",
            "-q",
        ],
        cwd=scratch,
        env={**os.environ, "PYTHONPATH": str(scratch)},
        capture_output=True,
        text=True,
    )
    print(
        "upstream container-detection baseline:",
        result.stdout.splitlines()[-1],
        flush=True,
    )
