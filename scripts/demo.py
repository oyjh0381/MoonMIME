"""Reproducible evidence preservation workflow; no extracted attachment files."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, required=True)
    args = parser.parse_args()
    binary = str(args.binary.resolve())
    source = ROOT / "examples/integrations/forensic-case.eml"
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    output = ROOT / ".private/demo"
    output.mkdir(parents=True, exist_ok=True)

    def run(*arguments, status=0):
        result = subprocess.run([binary, *map(str, arguments)], capture_output=True, timeout=30)
        if result.returncode != status:
            raise AssertionError((arguments, result.returncode, result.stdout, result.stderr))
        return result.stdout, json.loads(result.stdout)

    _, inventory = run("inventory", source, "--compatible")
    assert inventory["complete"]
    wire, manifest = run("capture", source, "DEMO-01", "preserved-message")
    sidecar = output / "manifest.json"
    sidecar.write_bytes(wire)
    _, valid = run("verify", source, sidecar, "DEMO-01", "preserved-message")
    assert valid["valid"] and valid["checked_attachments"] == 1
    _, invalid = run("verify", source, sidecar, "DEMO-01", "changed-label", status=3)
    assert not invalid["valid"]
    altered = output / "altered.eml"
    altered.write_bytes(source.read_bytes() + b"changed")
    _, changed = run("verify", altered, sidecar, "DEMO-01", "preserved-message", status=3)
    assert not changed["valid"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before == inventory["raw_sha256"] == manifest["raw_sha256"]
    # Sparse oversized file: rejection before payload buffer allocation.
    oversized = output / "oversized.eml"
    with oversized.open("wb") as stream:
        stream.seek(32 * 1024 * 1024)
        stream.write(b"x")
    _, failure = run("inventory", oversized, status=2)
    assert "error" in failure
    print(json.dumps(dict(schema="moonmime.demo.v1", entities=len(inventory["entities"]),
                          decoded_total=inventory["decoded_total"], attachments=valid["checked_attachments"],
                          original_unchanged=True, altered_source_rejected=True, altered_label_rejected=True,
                          oversized_file_rejected=True)))


if __name__ == "__main__":
    main()
