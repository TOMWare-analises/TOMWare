#!/usr/bin/env python3
"""Host/guest Pin-without-Pintool probe with a hard timeout."""
from __future__ import annotations

import hashlib
import json
import subprocess
import time
from pathlib import Path

PIN = Path(r"D:\MMB\workspace\tomware-melhorias\TOMWare\pin\intel64\bin\pin.exe")
ORACLE = Path(r"D:\MMB\workspace\tomware-melhorias\TOMWare\Resultados\Apps-Teste\TestAntiDebug.exe")
OUT = Path(r"D:\MMB\workspace\tomware-melhorias\TOMWare\experiment\results\oracles\guest\pin_bare_probe_host")
TIMEOUT = 30


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    h.update(p.read_bytes())
    return h.hexdigest().upper()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    cmd = [str(PIN), "--", str(ORACLE)]
    t0 = time.perf_counter()
    timed_out = False
    code = None
    stdout = b""
    stderr = b""
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            timeout=TIMEOUT,
            cwd=str(ORACLE.parent),
        )
        code = proc.returncode
        stdout = proc.stdout or b""
        stderr = proc.stderr or b""
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        stdout = exc.stdout or b""
        stderr = exc.stderr or b""
        subprocess.run(["taskkill", "/IM", "pin.exe", "/T", "/F"], capture_output=True)
        subprocess.run(["taskkill", "/IM", "pinbin.exe", "/T", "/F"], capture_output=True)
    duration_ms = int((time.perf_counter() - t0) * 1000)
    (OUT / "stdout.txt").write_bytes(stdout)
    (OUT / "stderr.txt").write_bytes(stderr)
    text_err = stderr.decode("utf-8", "replace")
    text_out = stdout.decode("utf-8", "replace")
    assert_hit = "StartServer" in text_err or "assertion failed" in text_err
    ok = (code == 0) and (not timed_out) and (not assert_hit) and ("OK" in text_out)
    verdict = "supported" if ok else "not_supported_by_engine"
    meta = {
        "campaign_id": "access_pin_bare_host",
        "machine": "host",
        "command": " ".join(cmd),
        "pin_path": str(PIN),
        "pin_sha256": sha256(PIN),
        "oracle_path": str(ORACLE),
        "oracle_sha256": sha256(ORACLE),
        "timeout_sec": TIMEOUT,
        "timed_out": timed_out,
        "exit_code": code,
        "duration_ms": duration_ms,
        "stdout_bytes": len(stdout),
        "stderr_bytes": len(stderr),
        "startserver_assert": assert_hit,
        "conclusion": verdict,
        "not_a_claim": "host probe is not the 9000 guest campaign",
    }
    (OUT / "run_meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    (OUT / "verdict.txt").write_text(
        "\n".join(f"{k}={v}" for k, v in meta.items()) + "\n", encoding="utf-8"
    )
    print(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()
