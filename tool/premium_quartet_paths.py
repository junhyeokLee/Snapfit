"""Resolve the optional, machine-local location of retained native proofs."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/premium-four-per-topic-20261103'


def review_root():
    location = OUT / 'native-review-location.json'
    return Path(json.loads(location.read_text())['directory']) if location.exists() else OUT / 'review'
