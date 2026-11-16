#!/usr/bin/env python3
"""Read back this content batch with anonymous and ordinary author sessions."""

import argparse
import json
from pathlib import Path
import struct
import sys
import urllib.parse

import publish_decorated_feed as publishing

EXISTING_WORK = "18b50ccd-0eac-467a-82ab-52dce0e87d7b"


def require(condition, message):
    if not condition:
        raise publishing.PublishError(message)


def media(public, work):
    require(work.get("mediaVersion") == 2 and len(work.get("mediaTokens", [])) == 1,
            "Unexpected public media capabilities")
    token = work["mediaTokens"][0]
    require(token.get("position") == 0, "Unexpected media position")
    query = urllib.parse.urlencode({"work": work["id"], "position": 0, "token": token["token"]})
    return public.call("GET", "/functions/v1/social-media?" + query, raw=True)


def has_private_keys(value):
    if isinstance(value, dict):
        return any(key in {"design", "layers", "originalUrl", "original_url"} or has_private_keys(item)
                   for key, item in value.items())
    return isinstance(value, list) and any(has_private_keys(item) for item in value)


def verify(manifest_path):
    manifest, rows, fingerprint = publishing.load_manifest(manifest_path)
    state_path = Path.home() / "Library/Application Support/SnapFit/content-publisher" / publishing.PROJECT / (publishing.BATCH + ".json")
    require(state_path.is_file() and not state_path.is_symlink(), "No completed batch credential journal")
    require(state_path.stat().st_mode & 0o777 == 0o600, "Credential journal permissions changed")
    state = json.loads(state_path.read_text())
    require(state.get("fingerprint") == fingerprint, "The verified files differ from the published batch")
    public_key, _ = publishing.project_keys()
    public = publishing.Api(public_key)
    feed = public.social("feed", {"limit": 30})
    feed_ids = {w["id"] for w in feed.get("items", [])}
    reports = []
    for row in rows:
        account = state["authors"][row["handle"]]
        uid, work_id = account["userId"], account["workId"]
        require(account.get("published") and work_id in feed_ids, "New post missing from the anonymous feed")
        work = public.social("work", {"id": work_id})
        require(work.get("status") == "published" and work.get("kind") == "moment", "Public work changed status or kind")
        require(work["author"]["userId"] == uid and work["author"]["handle"] == row["handle"] and
                work["author"]["displayName"] == row["displayName"], "Public author mapping changed")
        require(work.get("caption") == row["caption"], "Public caption differs")
        require(work.get("likeCount") == 0 and work.get("commentCount") == 0, "Interaction counts differ from the requested initial state")
        require(not has_private_keys(work) and "album-assets" not in json.dumps(work), "Private source leaked into a public response")
        require(work.get("sourceTemplate") is None, "Moment unexpectedly exposes an album template")
        png = media(public, work)
        require(publishing.digest(png) == publishing.digest(row["snapshot"]), "Public PNG differs from the reviewed raster")
        width, height = struct.unpack(">II", png[16:24])
        design_ratio = row["design"]["canvas"]["width"] / row["design"]["canvas"]["height"]
        require(abs(float(work["aspectRatio"]) - design_ratio) < .00001 and
                abs((width / height) / design_ratio - 1) < .003, "Public aspect ratio differs from the editable canvas")
        if row.get("avatar"):
            avatar_path = work["author"]["avatarPath"]
            require(avatar_path == f"{uid}/{account['avatarId']}.png", "Avatar is not the prepared account photo")
            signed = public.call("POST", "/storage/v1/object/sign/social-profile-photos/" + avatar_path, {"expiresIn": 60})
            signed_path = signed["signedURL"]
            require(signed_path.startswith("/object/sign/social-profile-photos/"), "Unexpected avatar signing destination")
            avatar = public.call("GET", "/storage/v1" + signed_path, raw=True)
            require(publishing.digest(avatar) == publishing.digest(row["avatar"]), "Anonymous avatar bytes differ")
        signed = public.call("POST", "/auth/v1/token?grant_type=password", {"email": account["email"], "password": account["password"]})
        require(signed["user"]["id"] == uid and signed["user"]["role"] == "authenticated", "Author login changed")
        user = publishing.Api(public_key, signed["access_token"])
        journal = user.rpc("get_moment_journal", {"p_month": manifest["recordDate"][:7] + "-01"})
        record = next((r for r in journal.get("records", []) if r["id"] == account["recordId"]), None)
        require(record is not None and record.get("owner_id") == uid and record.get("caption") == row["caption"], "Private record changed")
        photo = next((p for p in record["photos"] if p["id"] == account["photoId"]), None)
        require(photo is not None and photo.get("design") == row["design"], "Private editable layers were not preserved")
        require(photo["path"] == f"{uid}/moments/{account['recordId']}/{account['photoId']}.png", "Private original path changed")
        original = user.call("GET", "/storage/v1/object/authenticated/album-assets/" + photo["path"], raw=True)
        require(publishing.digest(original) == publishing.digest(row["original"]), "Private original bytes differ")
        reports.append({"id": row["id"], "workId": work_id, "userId": uid, "displayName": row["displayName"],
                        "handle": row["handle"], "anonymousFeed": True, "anonymousWork": True,
                        "publicPngSha256": publishing.digest(png), "snapshotMatches": True,
                        "publicWidth": width, "publicHeight": height, "aspectRatioMatches": True,
                        "avatarMatches": bool(row.get("avatar")), "privateOriginalMatches": True,
                        "privateEditableLayers": len(photo["design"]["layers"]), "privateDesignMatches": True,
                        "publicResponseHasNoPrivateDesign": True, "likeCount": 0, "commentCount": 0})
    require(len({r["userId"] for r in reports}) == 4 and len({r["workId"] for r in reports}) == 4,
            "The four posts must have four distinct authors")
    existing = public.social("work", {"id": EXISTING_WORK})
    require(existing and existing["id"] in feed_ids and existing.get("status") == "published", "Existing public work is missing")
    report = {"batchId": publishing.BATCH, "verifiedPosts": 4, "distinctAuthors": 4,
              "existingWorkId": EXISTING_WORK, "existingWorkPreserved": True, "posts": reports}
    report_path = manifest_path.parent / "publication-verification.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    return report_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    try:
        print(verify(args.manifest.resolve()))
    except publishing.PublishError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        print("Verification stopped: " + type(error).__name__, file=sys.stderr)
        sys.exit(1)
