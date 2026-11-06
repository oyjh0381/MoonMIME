"""Run the public demo, independent module, oracles and optional resource probe.
No credentials, package publication, repository pushes or network access here.
"""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--moon-wrapper", type=Path, help="optional Windows path-normalization .ps1 adapter")
    parser.add_argument("--skip-resources", action="store_true")
    args = parser.parse_args()
    moon = ["pwsh", "-NoProfile", "-File", str(args.moon_wrapper.resolve())] if args.moon_wrapper else ["moon"]

    def run(command):
        subprocess.run(command, cwd=ROOT, check=True, timeout=240)

    run(moon + ["build", "--target", "native", "--release", "--deny-warn", "--frozen"])
    for target in ("wasm-gc", "native"):
        run(moon + ["run", "consumers/mailroom", "--target", target, "--deny-warn", "--frozen"])
    candidates = list((ROOT / "_build/native/release/build").rglob("moonmime-evidence.exe"))
    # Native outputs use .exe on Windows; allow a suffixless toolchain too.
    candidates += list((ROOT / "_build/native/release/build").rglob("moonmime-evidence"))
    candidates = [path for path in candidates if path.is_file()]
    if not candidates:
        raise RuntimeError("Native evidence executable not found")
    binary = max(candidates, key=lambda p: p.stat().st_mtime_ns)
    for script in ["demo.py", "differential.py"] + ([] if args.skip_resources else ["resource_probe.py"]):
        run([sys.executable, str(ROOT / "scripts" / script), "--binary", str(binary)])
    print("MoonMIME public workflows verified; generated evidence stays in .private/.")


if __name__ == "__main__":
    main()
