"""Install only verified official Linux archives during an uncredentialed build."""
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse


def checked_archive(pins, name):
    value = pins[name]
    url = urlparse(value["url"])
    allowed = "nodejs.org" if name == "node" else "storage.googleapis.com"
    digest = value["sha256"]
    if url.scheme != "https" or url.hostname != allowed or url.port or url.username:
        raise ValueError("invalid_runtime_archive")
    if len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
        raise ValueError("invalid_runtime_digest")
    return value


def install():
    pins = json.loads(Path("/tmp/runtime-pins.json").read_text())
    if pins.get("platform") != "linux-x64":
        raise ValueError("linux_x64_runtime_required")
    for name in ("node", "flutter"):
        value = checked_archive(pins, name)
        with tempfile.TemporaryDirectory(prefix="snapfit-runtime-") as directory:
            archive = Path(directory) / "runtime.tar.xz"
            subprocess.run([
                "curl", "--fail", "--silent", "--show-error", "--location",
                "--proto", "=https", "--proto-redir", "=https", "--retry", "2",
                "--output", str(archive), value["url"],
            ], check=True)
            digest = hashlib.file_digest(archive.open("rb"), "sha256").hexdigest()
            if digest != value["sha256"]:
                raise ValueError("runtime_archive_digest_mismatch")
            arguments = ["tar", "-xJf", str(archive)]
            arguments += ["--strip-components=1", "-C", "/opt/node"] if name == "node" else ["-C", "/opt"]
            subprocess.run(arguments, check=True)


if __name__ == "__main__":
    install()
