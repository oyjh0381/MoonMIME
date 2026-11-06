"""Run two independent, development-only MIME oracles against original fixtures.

Only reviewed, exact divergence signatures may pass. No difference is labelled a
vulnerability. Reports/fixtures remain in .private; run from the repository root.
"""
import argparse
import base64
import email.policy
from email.parser import BytesParser
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def corpus():
    cases = []

    def add(name, raw, review=None):
        cases.append(dict(name=name, raw=raw, review=review))

    def message(payload, encoding, filename="sample.bin", extra=b""):
        return (b'MIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary="mix"\r\n\r\n'
                b'--mix\r\nContent-Type: text/plain\r\n\r\nhello\r\n'
                b'--mix\r\nContent-Type: application/octet-stream\r\n'
                b'Content-Disposition: attachment; filename="' + filename.encode() + b'"\r\n'
                b'Content-Transfer-Encoding: ' + encoding + b'\r\n' + extra + b'\r\n' + payload +
                b'\r\n--mix--\r\n')

    # Worked inputs with known bytes, including all octets. No external mail data.
    for index, data in enumerate([b"", b"hello", b"\x00\xff\x80\x01", bytes(range(256)), b"A" * 4097]):
        encoded = base64.b64encode(data)
        add(f"base64-{index}", message(encoded, b"base64"))
        folded = b"\r\n".join(encoded[i:i + 76] for i in range(0, len(encoded), 76))
        add(f"base64-folded-{index}", message(folded, b"base64"))
    for index, data in enumerate([b"hello", b"=00=FF=80=01", b"abc=\r\ndef", b"a=3Db", b"=C3=A9"]):
        add(f"qp-{index}", message(data, b"quoted-printable"))
    for encoding in [b"7bit", b"8bit", b"binary"]:
        add(encoding.decode(), message(b"safe inert content", encoding))
    add("folded-header", message(b"aGVsbG8=", b"base64", extra=b"X-Label: first\r\n second\r\n"))
    add("mixed-case", message(b"aGVsbG8=", b"BaSe64"))
    add("rfc2231", message(b"aGVsbG8=", b"base64").replace(
        b'filename="sample.bin"', b"filename*=utf-8''caf%C3%A9.bin"))
    inner = message(b"AAEC", b"base64")
    add("nested-multipart", b'Content-Type: multipart/mixed; boundary=outer\r\n\r\n--outer\r\n' + inner + b'\r\n--outer--\r\n')
    add("preamble-epilogue", message(b"AAEC", b"base64").replace(b"\r\n\r\n--mix", b"\r\n\r\npreamble\r\n--mix", 1) + b"epilogue")
    add("plain", b"Subject: example\r\n\r\nhello")
    add("base64-invalid", message(b"aGVs!bG8=", b"base64"), "Malformed transfer input: acceptance/decoding policy, not a vulnerability verdict.")
    add("base64-unpadded", message(b"aGVsbG8", b"base64"), "Padding recovery differs; inspect decoded hashes and diagnostics.")
    add("qp-invalid", message(b"abc=ZZ", b"quoted-printable"), "Malformed escape preservation versus explicit unavailable decoding.")
    add("unknown-transfer", message(b"inert", b"x-private"), "Unknown encoding is intentionally unavailable in MoonMIME inventory.")
    add("duplicate-type", message(b"AAEC", b"base64", extra=b"Content-Type: text/plain\r\n"), "Conflicting duplicate header selection differs across parsers.")
    add("encoded-message", b"Content-Type: message/rfc822\r\nContent-Transfer-Encoding: base64\r\n\r\n" + base64.b64encode(b"Subject: nested\r\n\r\nhello"), "Encoded embedded messages are opaque source evidence in MoonMIME.")
    add("bare-lf", message(b"aGVsbG8=", b"base64").replace(b"\r\n", b"\n"), "Line ending recovery must be visible, even if payloads agree.")
    add("missing-close", message(b"aGVsbG8=", b"base64").replace(b"--mix--\r\n", b""), "Missing delimiter recovery differs; agreement is limited to observations.")
    return cases


def python_observe(raw):
    message = BytesParser(policy=email.policy.default).parsebytes(raw)
    entities = []

    def walk(item, path):
        children = item.get_payload() if item.is_multipart() else []
        payload = None if children else item.get_payload(decode=True)
        entities.append(dict(path=path, media_type=item.get_content_type(), filename=item.get_filename(),
                             decoded_sha256=None if payload is None else digest(payload)))
        for index, child in enumerate(children):
            walk(child, path + [index])
    walk(message, [])
    return entities


def run_json(command):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError(f"oracle failed ({result.returncode}): {result.stderr.decode(errors='replace')[:600]}")
    return json.loads(result.stdout)


def project_entities(inventory):
    return [{key: entity[key] for key in ("path", "media_type", "filename", "decoded_sha256")}
            for entity in inventory["entities"]]


def attachment_view(inventory):
    return [dict(filename=e["filename"], media_type=e["media_type"], decoded_sha256=e["decoded_sha256"])
            for e in inventory["entities"] if e["kind"] == "leaf" and
            (e["filename"] is not None or e["disposition"] == "attachment")]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--node", default="node")
    args = parser.parse_args()
    output = ROOT / ".private" / "differential"
    output.mkdir(parents=True, exist_ok=True)
    reviewed_path = ROOT / "scripts" / "oracles" / "reviewed-differences.json"
    reviewed = json.loads(reviewed_path.read_text()) if reviewed_path.exists() else {}
    rows, failures = [], []
    for case in corpus():
        raw = case["raw"]
        path = output / (case["name"] + ".eml")
        path.write_bytes(raw)
        moon = run_json([str(args.binary.resolve()), "inventory", str(path), "--compatible"])
        if moon["raw_sha256"] != digest(raw):
            raise AssertionError("raw fingerprint mismatch")
        for entity in moon["entities"]:
            start, end = entity["body_start"], entity["body_end"]
            if not 0 <= start <= end <= len(raw) or digest(raw[start:end]) != entity["encoded_sha256"]:
                raise AssertionError((case["name"], "encoded region fingerprint mismatch"))
        py = python_observe(raw)
        node = run_json([args.node, str(ROOT / "scripts/oracles/mailparser.cjs"), str(path)])["attachments"]
        comparisons = dict(python_tree=project_entities(moon) == py,
                           mailparser_attachments=attachment_view(moon) == node)
        observations = dict(moon=project_entities(moon), python=py, mailparser=node,
                            diagnostics=moon["diagnostics"], complete=moon["complete"],
                            decoding=[(e["decode_status"], e["decode_error"]) for e in moon["entities"]])
        signature = digest(json.dumps(observations, sort_keys=True, ensure_ascii=True).encode())
        key = case["name"]
        if case["review"]:
            accepted = reviewed.get(key, {}).get("signature") == signature
            classification = "reviewed-policy-observation" if accepted else "requires-review"
        else:
            accepted = all(comparisons.values()) and moon["complete"]
            classification = "agreement" if accepted else "unexpected-difference"
        if not accepted:
            failures.append(key)
        rows.append(dict(name=key, raw_sha256=digest(raw), bytes=len(raw), comparisons=comparisons,
                         classification=classification, signature=signature,
                         rationale=reviewed.get(key, {}).get("rationale", case["review"]),
                         observations=observations))
    report = dict(schema="moonmime.differential.v1", python=platform.python_version(),
                  node=subprocess.check_output([args.node, "--version"], text=True).strip(),
                  mailparser=json.loads((ROOT / "scripts/oracles/node_modules/mailparser/package.json").read_text())["version"],
                  cases=len(rows), agreement=sum(r["classification"] == "agreement" for r in rows),
                  reviewed=sum(r["classification"] == "reviewed-policy-observation" for r in rows),
                  failures=failures, results=rows)
    (output / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "results"}))
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
