"""Fail closed on MCP/application errors and assertion failures in a completed workflow."""
import argparse
import json
from pathlib import Path


def decode(text):
    for _ in range(5):
        if not isinstance(text, str):
            return text
        try:
            text = json.loads(text)
        except ValueError:
            return text
    return text

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--expect-input", action="store_true")
    args = parser.parse_args()
    results = {}
    total = 0
    errors = []
    steps = sorted(args.evidence.glob("step-*.json"))
    stopped = any("stop_scene" in p.name for p in steps)
    for path in steps:
        receipt = json.loads(path.read_text())
        if receipt.get("isError") or receipt.get("application_error"):
            errors.append(path.name)
        for block in receipt.get("content", []):
            value = decode(block.get("text"))
            if not isinstance(value, dict):
                continue
            suites = value if "core" in value else {"input": value} if "results" in value and "checks" in value else {}
            for name, suite in suites.items():
                if not isinstance(suite, dict) or "checks" not in suite:
                    continue
                results[name] = suite
                if suite.get("failures"):
                    errors.append({path.name: suite["failures"]})
    if not stopped:
        errors.append("workflow did not reach stop_scene")
    if "core" not in results:
        errors.append("no actual core test result")
    if args.expect_input and "input" not in results:
        errors.append("no actual input report")
    total = sum(suite["checks"] for suite in results.values())
    print(json.dumps({"checks": total, "suites": {k:v["checks"] for k,v in results.items()}, "errors":errors}, ensure_ascii=False, indent=2))
    raise SystemExit(1 if errors else 0)
