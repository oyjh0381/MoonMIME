"""Measure full Native evidence CLI, including startup/I/O/hash/JSON, not parser-only speed.
Windows memory is OS peak working set; Linux /proc high-water sampling is a lower bound.
"""
import argparse
import ctypes
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def peak_bytes(process):
    if os.name == "nt":
        class Counters(ctypes.Structure):
            _fields_ = [("cb", ctypes.c_ulong), ("faults", ctypes.c_ulong)] + [
                (name, ctypes.c_size_t) for name in ("peak", "working", "paged_peak", "paged",
                                                   "nonpaged_peak", "nonpaged", "pagefile", "pagefile_peak")]
        counters = Counters()
        counters.cb = ctypes.sizeof(counters)
        api = ctypes.WinDLL("psapi").GetProcessMemoryInfo
        api.argtypes = [ctypes.c_void_p, ctypes.POINTER(Counters), ctypes.c_ulong]
        api.restype = ctypes.c_int
        if api(int(process._handle), ctypes.byref(counters), counters.cb):
            return counters.peak
    else:
        try:
            for line in Path(f"/proc/{process.pid}/status").read_text().splitlines():
                if line.startswith("VmHWM:"):
                    return int(line.split()[1]) * 1024
        except (FileNotFoundError, ProcessLookupError):
            pass
    return 0


def measure(binary, path):
    with tempfile.TemporaryFile() as output:
        start = time.perf_counter()
        process = subprocess.Popen([str(binary), "inventory", str(path)], stdout=output, stderr=subprocess.PIPE)
        peak = 0
        while process.poll() is None:
            peak = max(peak, peak_bytes(process))
            if time.perf_counter() - start > 60:
                process.kill()
                process.wait()
                raise TimeoutError(path.name)
            time.sleep(0.002)
        peak = max(peak, peak_bytes(process))
        elapsed = (time.perf_counter() - start) * 1000
        stderr = process.stderr.read()
        process.stderr.close()
        output.seek(0)
        result = json.load(output)
        if process.returncode:
            raise RuntimeError((path.name, result, stderr))
        return elapsed, peak, result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--rounds", type=int, default=5)
    args = parser.parse_args()
    if not 3 <= args.rounds <= 20:
        parser.error("rounds must be 3..20")
    directory = ROOT / ".private/resource-probe"
    directory.mkdir(parents=True, exist_ok=True)
    rows = []
    for size in (65536, 262144, 1048576, 4194304):
        raw = b"Content-Transfer-Encoding: binary\r\n\r\n" + b"a" * size
        path = directory / f"payload-{size}.eml"
        path.write_bytes(raw)
        measure(args.binary.resolve(), path)  # warmup excluded
        samples = [measure(args.binary.resolve(), path) for _ in range(args.rounds)]
        if any(not result[2]["complete"] or result[2]["decoded_total"] != size for result in samples):
            raise AssertionError("payload did not finish decoding")
        times = sorted(row[0] for row in samples)
        rows.append(dict(payload_bytes=size, rounds=args.rounds, p50_ms=statistics.median(times),
                         max_ms=max(times), peak_working_set_bytes=max(row[1] for row in samples),
                         elapsed_ms=times))
    report = dict(schema="moonmime.resource.v1", platform=platform.platform(), python=platform.python_version(),
                  memory_method="OS PeakWorkingSetSize" if os.name == "nt" else "sampled /proc VmHWM lower bound",
                  scope="Native release CLI startup + bounded file I/O + inventory + decoding + SHA256 + JSON; synthetic identity payloads",
                  results=rows)
    (directory / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
