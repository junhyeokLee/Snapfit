#!/usr/bin/env python3
"""Replace only the reviewed artwork on the four existing content records.

The original credential journal is read-only. No Auth Admin, profile mutation,
original upload, entitlement change, SQL write, or Storage overwrite is used.
Default is offline validation; --preflight adds ordinary sign-in and reads.
--execute updates the existing records with revision checks and publishes new
immutable snapshots. Their predecessors remain private historical publications.
"""
import argparse
import copy
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

import publish_decorated_feed as publishing
import verify_decorated_feed as verification

UPDATE_BATCH = "social-more-20261103-v3"
ORIGINAL_MANIFEST = publishing.ROOT / "output/decorated-feed-20261103-v2/publish-manifest.json"
FREE_STICKERS = {"stickerBlueStar", "stickerHeartRed", "stickerLeafGreen", "stickerFlowerPink",
                 "stickerPaperClip", "stickerTapeBeige", "stickerCloudSoft", "stickerCloverGreen"}


def require(value, message):
    if not value:
        raise publishing.PublishError(message)


def state_directory():
    return Path.home() / "Library/Application Support/SnapFit/content-publisher" / publishing.PROJECT


def credential_path():
    return state_directory() / (publishing.BATCH + ".json")


def credentials():
    path = credential_path()
    require(path.is_file() and not path.is_symlink(), "Original credential journal missing")
    require(path.stat().st_mode & 0o777 == 0o600, "Original credential journal permissions changed")
    data = path.read_bytes()
    state = json.loads(data)
    _, _, original_fingerprint = publishing.load_manifest(ORIGINAL_MANIFEST)
    require(state["fingerprint"] == original_fingerprint, "Original publication journal does not match the original reviewed files")
    require(all(state["authors"].get(author[1], {}).get("published") for author in publishing.AUTHORS.values()),
            "All four original publications must already exist")
    return state, publishing.digest(data)


def public_key():
    # The update needs only a public key; it never constructs an admin client.
    result = subprocess.run(["supabase", "projects", "api-keys", "--project-ref", publishing.PROJECT, "--output", "json"],
                            capture_output=True, text=True, timeout=45)
    require(result.returncode == 0, "Public project key lookup failed")
    rows = json.loads(result.stdout)
    key = next((r["api_key"] for r in rows if r.get("type") == "publishable" and not r.get("disabled")), None)
    key = key or next((r["api_key"] for r in rows if r.get("name") == "anon" and not r.get("disabled")), None)
    require(key, "Enabled public project key unavailable")
    return key


def prepare(source):
    target = publishing.prepare_manifest(source)
    value = json.loads(target.read_text())
    _, old_rows, _ = publishing.load_manifest(ORIGINAL_MANIFEST)
    baseline = {row["id"]: row for row in old_rows}
    original = json.loads(ORIGINAL_MANIFEST.read_text())
    original_rows = {row["id"]: row for row in original["posts"]}
    for row in value["posts"]:
        old, old_manifest = baseline[row["id"]], original_rows[row["id"]]
        for field in ("caption", "displayName", "handle", "bio"):
            row[field] = old[field]
        for field in ("originalPng", "avatarPng"):
            row[field] = os.path.relpath((ORIGINAL_MANIFEST.parent / old_manifest[field]).resolve(), target.parent)
    value["revisionBatchId"] = UPDATE_BATCH
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    return target


def load(path):
    manifest, rows, fingerprint = publishing.load_manifest(path)
    require(manifest.get("revisionBatchId") == UPDATE_BATCH, "Unexpected artwork revision batch")
    _, old_rows, _ = publishing.load_manifest(ORIGINAL_MANIFEST)
    baseline = {row["id"]: row for row in old_rows}
    for row in rows:
        old = baseline[row["id"]]
        for field in ("caption", "displayName", "handle", "bio", "width", "height"):
            require(row[field] == old[field], "This revision may only change artwork: " + field)
        for field in ("original", "avatar"):
            require(row[field] == old[field], "Original photograph or avatar changed")
        require(row["design"] != old["design"] and row["snapshot"] != old["snapshot"], "Artwork revision is unchanged")
        for layer in row["design"]["layers"]:
            if layer["type"] == "DECORATION":
                require(layer["payload"].get("imageBackground") in FREE_STICKERS, "Unsupported procedural sticker")
    return manifest, rows, fingerprint, baseline


def read_record(user, account):
    journal = user.rpc("get_moment_journal", {"p_month": "2026-11-01"})
    record = next((row for row in journal.get("records", []) if row["id"] == account["recordId"]), None)
    require(record is not None and record.get("owner_id") == account["userId"], "Owned record missing")
    require(len(record["photos"]) == 1 and record["photos"][0]["id"] == account["photoId"], "Original photograph identity changed")
    return record


def profile_fields(profile):
    return {key: profile.get(key) for key in ("userId", "displayName", "handle", "bio", "avatarPath")}


def preflight(manifest, rows, baseline, source, credential_hash, fingerprint, revision=None):
    key = public_key()
    public = publishing.Api(key)
    revision = copy.deepcopy(revision) if revision else {"batchId": UPDATE_BATCH, "fingerprint": fingerprint,
                                                       "credentialJournalSha256": credential_hash, "accounts": {}}
    require(revision["fingerprint"] == fingerprint and revision["credentialJournalSha256"] == credential_hash,
            "Revision files or the original credential journal changed")
    frames = sorted({layer["payload"]["imageBackground"] for row in rows for layer in row["design"]["layers"]
                     if layer["type"] == "IMAGE" and layer["payload"].get("imageBackground")})
    if frames:
        query = publishing.urllib.parse.urlencode({"product_key": "in.(" + ",".join("frame:" + frame for frame in frames) + ")",
                                                   "select": "product_key,point_price,is_active,kind"})
        products = public.call("GET", "/rest/v1/point_shop_products?" + query)
        allowed = {p["product_key"] for p in products if p.get("kind") == "frame" and p.get("point_price") == 0 and p.get("is_active") is True}
        require(allowed == {"frame:" + f for f in frames}, "Every frame must already be active and free; no rights will be granted")
    sessions = {}
    for row in rows:
        handle = row["handle"]
        account = source["authors"][handle]
        signed = public.call("POST", "/auth/v1/token?grant_type=password", {"email": account["email"], "password": account["password"]})
        require(signed["user"]["id"] == account["userId"] and signed["user"]["role"] == "authenticated", "Existing author login changed")
        user = publishing.Api(key, signed["access_token"])
        require(user.call("GET", "/auth/v1/user")["id"] == account["userId"], "Existing author session changed")
        profile = user.social("profile", {"userId": account["userId"]})
        expected_profile = {"userId": account["userId"], "displayName": row["displayName"], "handle": handle,
                            "bio": row["bio"], "avatarPath": f"{account['userId']}/{account['avatarId']}.png"}
        require(profile_fields(profile) == expected_profile, "Existing public profile changed; left untouched")
        current = read_record(user, account)
        require(current["caption"] == row["caption"] and current["record_date"][:10] == manifest["recordDate"], "Existing caption or record date changed")
        photo = current["photos"][0]
        expected_path = f"{account['userId']}/moments/{account['recordId']}/{account['photoId']}.png"
        require(photo["path"] == expected_path and (photo["width"], photo["height"]) == (row["width"], row["height"]), "Original path or dimensions changed")
        original = user.call("GET", "/storage/v1/object/authenticated/album-assets/" + photo["path"], raw=True)
        require(original == row["original"], "Private original bytes changed")
        old_work = user.social("work", {"id": account["workId"]})
        require(old_work and old_work["author"]["userId"] == account["userId"], "Original publication no longer belongs to this account")
        item = revision["accounts"].get(handle)
        if item is None:
            require(photo.get("design") == baseline[row["id"]]["design"] and old_work["status"] == "published", "Record was edited outside this revision batch")
            item = {"userId": account["userId"], "recordId": account["recordId"], "photoId": account["photoId"],
                    "beforeRevision": current["revision"], "oldWorkId": account["workId"], "oldStatusBefore": old_work["status"],
                    "requestId": str(uuid.uuid4()), "profileBefore": expected_profile,
                    "oldSnapshotSha256": publishing.digest(verification.media(user, old_work))}
            revision["accounts"][handle] = item
        else:
            before = current["revision"] == item["beforeRevision"] and photo.get("design") == baseline[row["id"]]["design"]
            after = current["revision"] == item["beforeRevision"] + 1 and photo.get("design") == row["design"]
            require(before or after, "Record revision conflict; no unrelated edit will be overwritten")
        sessions[handle] = user
    return revision, sessions, public


def execute(manifest, rows, fingerprint, baseline, manifest_path):
    original_state, credential_hash = credentials()
    directory = state_directory()
    revision_path = directory / (UPDATE_BATCH + ".json")
    lock_fd = os.open(directory / (UPDATE_BATCH + ".lock"), os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(lock_fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise publishing.PublishError("This artwork revision is already running") from None
        require(not revision_path.is_symlink(), "Refusing a linked revision journal")
        existing = json.loads(revision_path.read_text()) if revision_path.exists() else None
        revision, sessions, public = preflight(manifest, rows, baseline, original_state, credential_hash, fingerprint, existing)
        publishing.save_private_state(revision_path, revision)
        # All four author/record/material checks finish before the first edit.
        for row in rows:
            user, item = sessions[row["handle"]], revision["accounts"][row["handle"]]
            account = original_state["authors"][row["handle"]]
            current = read_record(user, account)
            photo = copy.deepcopy(current["photos"][0])
            photo["design"] = row["design"]
            saved = user.rpc("save_weekly_moment", {"p_id": account["recordId"], "p_record_date": manifest["recordDate"],
                "p_caption": row["caption"], "p_photos": [photo], "p_expected_revision": item["beforeRevision"]})
            require(saved["revision"] == item["beforeRevision"] + 1 and saved["photos"][0]["design"] == row["design"], "Updated record did not confirm its revision/design")
            item["afterRevision"] = saved["revision"]
            publishing.save_private_state(revision_path, revision)
            draft = user.social("beginMomentPublication", {"recordId": account["recordId"], "photoId": account["photoId"],
                "expectedRevision": saved["revision"], "requestId": item["requestId"]})
            require(draft["id"] != item["oldWorkId"], "Revision must use a new immutable snapshot publication")
            item["newWorkId"] = draft["id"]
            publishing.save_private_state(revision_path, revision)
            if draft["status"] == "draft":
                upload = user.social("publicationUploadPath", {"id": draft["id"], "position": 0})
                expected = f"{account['userId']}/{draft['id']}/0.png"
                require(upload.get("path") == expected, "Snapshot path is not owned by this author")
                if not upload.get("uploaded"):
                    publishing.immutable_upload(user, "social-snapshots", expected, row["snapshot"])
                new_work = user.social("finalizePublication", {"id": draft["id"]})
            elif draft["status"] == "published":
                new_work = user.social("work", {"id": draft["id"]})
            else:
                raise publishing.PublishError("Revised publication visibility changed outside this batch")
            require(new_work["status"] == "published" and new_work["author"]["userId"] == account["userId"], "Revised publication did not confirm")
            old_work = user.social("work", {"id": item["oldWorkId"]})
            require(old_work and old_work["status"] == "private", "Predecessor must remain a private historical publication")
            item.update({"oldStatusAfter": old_work["status"], "newStatus": new_work["status"]})
            publishing.save_private_state(revision_path, revision)
            print(json.dumps({"id": row["id"], "handle": row["handle"], "recordId": account["recordId"],
                "oldWorkId": item["oldWorkId"], "newWorkId": item["newWorkId"], "oldStatus": "private", "newStatus": "published"}, ensure_ascii=False), flush=True)
        feed = public.social("feed", {"limit": 30})
        feed_ids = {w["id"] for w in feed["items"]}
        reports = []
        for row in rows:
            user, item = sessions[row["handle"]], revision["accounts"][row["handle"]]
            account = original_state["authors"][row["handle"]]
            require(item["newWorkId"] in feed_ids and item["oldWorkId"] not in feed_ids, "Anonymous feed contains a duplicate or missing revised post")
            work = public.social("work", {"id": item["newWorkId"]})
            png = verification.media(public, work)
            require(png == row["snapshot"] and work["caption"] == row["caption"], "Public revision bytes or caption differ")
            expected_ratio = row["design"]["canvas"]["width"] / row["design"]["canvas"]["height"]
            require(abs(float(work["aspectRatio"]) - expected_ratio) < .00001, "Public revision aspect ratio differs from its canvas")
            require(work.get("likeCount") == 0 and work.get("commentCount") == 0, "New publication interaction counts changed")
            require(not verification.has_private_keys(work) and "album-assets" not in json.dumps(work), "Private artwork metadata leaked")
            require(profile_fields(user.social("profile", {"userId": account["userId"]})) == item["profileBefore"], "Existing profile changed")
            current = read_record(user, account)
            require(current["revision"] == item["afterRevision"] and current["photos"][0]["design"] == row["design"], "Editable revision was not retained")
            old_work = user.social("work", {"id": item["oldWorkId"]})
            require(old_work["status"] == "private" and publishing.digest(verification.media(user, old_work)) == item["oldSnapshotSha256"], "Historical snapshot changed")
            require(public.social("work", {"id": item["oldWorkId"]}) is None, "Historical private work remains anonymously visible")
            reports.append({"id": row["id"], "handle": row["handle"], **item,
                            "snapshotSha256": publishing.digest(png), "editableLayerCount": len(row["design"]["layers"]),
                            "publicRasterMatches": True, "editableDesignMatches": True, "profilePreserved": True,
                            "aspectRatioMatches": True, "likeCount": 0, "commentCount": 0,
                            "captionPreserved": True, "originalPreserved": True, "historicalSnapshotPreserved": True,
                            "oldWorkAnonymousAccessRevoked": True})
        require(publishing.digest(credential_path().read_bytes()) == credential_hash, "Original credential journal was unexpectedly modified")
        report = {"batchId": UPDATE_BATCH, "projectRef": publishing.PROJECT, "status": "republished-and-verified",
                  "originalCredentialJournalUnchanged": True, "newAccountsCreated": 0, "publicPostDuplicates": 0,
                  "profilesModified": False, "originalsUploadedOrReplaced": False, "entitlementsChanged": False,
                  "posts": reports}
        target = manifest_path.parent / "republication-report.json"
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare-manifest", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--preflight", action="store_true")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    require(not (args.execute and args.preflight), "Choose preflight or execute")
    if args.prepare_manifest:
        require(not (args.manifest or args.execute or args.preflight), "Manifest conversion must run separately")
        print(prepare(args.prepare_manifest.resolve()))
        return
    require(args.manifest, "--manifest is required")
    path = args.manifest.resolve()
    manifest, rows, fingerprint, baseline = load(path)
    if args.execute:
        print(execute(manifest, rows, fingerprint, baseline, path))
    elif args.preflight:
        source, credential_hash = credentials()
        revision_path = state_directory() / (UPDATE_BATCH + ".json")
        require(not revision_path.is_symlink(), "Refusing a linked revision journal")
        existing = json.loads(revision_path.read_text()) if revision_path.exists() else None
        preflight(manifest, rows, baseline, source, credential_hash, fingerprint, existing)
        print(json.dumps({"mode": "normal-author-read-preflight", "verifiedAccounts": 4, "writes": 0, "fingerprint": fingerprint}))
    else:
        print(json.dumps({"mode": "offline-validation", "fingerprint": fingerprint,
                          "posts": [{"id": r["id"], "handle": r["handle"], "editableLayers": len(r["design"]["layers"])} for r in rows]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except publishing.PublishError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        print("Artwork revision stopped: " + type(error).__name__, file=sys.stderr)
        sys.exit(1)
