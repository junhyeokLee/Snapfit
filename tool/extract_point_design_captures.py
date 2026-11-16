"""Extract opt-in actual-widget PNGs from redirected Flutter browser QA logs."""
import base64
import json
from pathlib import Path
import re
import sys

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
destination.mkdir(parents=True, exist_ok=True)
prefix = "SNAPFIT_MEMORY_IMAGE_V1:"
saved = []
for line in source.read_text().splitlines():
    if prefix not in line:
        continue
    record = json.loads(line.split(prefix, 1)[1])
    name = record.get("id", "")
    if not name.startswith("points-web-") or not re.fullmatch(r"[a-z0-9-]+", name):
        continue
    pixels = base64.b64decode(record["base64"], validate=True)
    if not pixels.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Invalid PNG for {name}")
    output = destination / f"{name}.png"
    output.write_bytes(pixels)
    saved.append(str(output.resolve()))
if not saved:
    raise SystemExit("No points widget captures were found in the QA log")
print("\n".join(saved))
