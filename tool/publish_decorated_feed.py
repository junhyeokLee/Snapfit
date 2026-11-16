#!/usr/bin/env python3
"""Publish the reviewed November 3 content set through ordinary user RPCs.

Default: offline validation only. --execute provisions only the four explicitly
authorized fictional authors, then signs in normally for every storage/RPC call.
No invitation, recovery email, SQL write, service-role storage, or existing-user
update is performed. Passwords live in a mode-0600 journal outside the checkout;
API keys and access tokens stay in process memory and never enter the journal.

References checked 2026-11-03:
https://supabase.com/docs/reference/javascript/auth-admin-createuser
https://supabase.com/docs/reference/javascript/auth-signinwithpassword
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import ssl
import struct
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
PROJECT = "rrbhxdtriummqpztpjrk"
BASE = f"https://{PROJECT}.supabase.co"
BATCH = "social-more-20261103"
AUTHORS = {
    "dog02-postcard": ("보리랑", "bori.walks", "보리랑 천천히 걷고 오래 구경해요 🐾"),
    "sky04-dusk": ("준", "jun.afterwork", "퇴근길에 주로 하늘을 찍어요"),
    "flowers07-paper": ("다은", "daeun.smallroom", "작은 집에서 발견한 좋아하는 것들"),
    "sorting10-archive": ("하린", "harin.keeps", "오래 보고 싶은 장면을 모아요"),
}


class PublishError(Exception):
    pass


class ApiError(PublishError):
    def __init__(self, status, code="request_failed"):
        self.status = status
        self.code = code if re.fullmatch(r"[A-Za-z0-9_.-]{1,100}", str(code)) else "request_failed"
        super().__init__(f"HTTP {status}: {self.code}")


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def checked_png(path, *, original=False):
    data = path.read_bytes()
    limit = 12 if original else 8
    if not 24 <= len(data) <= limit * 1024 * 1024 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise PublishError("Invalid or oversized PNG: " + path.name)
    width, height = struct.unpack(">II", data[16:24])
    edge = 2560 if original else 8000
    pixels = 40000000 if original else 32000000
    if min(width, height) < 1 or max(width, height) > edge or width * height > pixels:
        raise PublishError("PNG dimensions exceed the app limits: " + path.name)
    offset, ended = 8, False
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        chunk = data[offset + 4:offset + 8]
        if offset + length + 12 > len(data):
            raise PublishError("Truncated PNG: " + path.name)
        # Originals must already have passed the app's prepareMomentPhoto codec.
        if original and chunk not in {b"IHDR", b"IDAT", b"IEND", b"sBIT", b"sRGB", b"gAMA", b"cHRM", b"pHYs"}:
            raise PublishError("Use prepareMomentPhoto's prepared copy: " + path.name)
        offset += length + 12
        if chunk == b"IEND":
            ended = offset == len(data)
            break
    if not ended:
        raise PublishError("Invalid PNG ending: " + path.name)
    return data, width, height


def prepare_manifest(source_path):
    source_path = source_path.resolve()
    source = json.loads(source_path.read_text())
    posts = []
    for row in source["posts"]:
        if row["id"] not in AUTHORS:
            raise PublishError("Unexpected source post")
        name, handle, default_bio = AUTHORS[row["id"]]
        author = row.get("author", {})
        prepared = row.get("preparedOriginalPath")
        original = (ROOT / prepared).resolve() if prepared else source_path.parent / (row["id"] + ".original.png")
        posts.append({
            "id": row["id"], "displayName": name, "handle": handle,
            "bio": author.get("bio", row.get("bio", default_bio)),
            "caption": row["caption"].replace("\\n", "\n"),
            "originalPng": os.path.relpath(original, source_path.parent),
            "snapshotPng": os.path.relpath(ROOT / row["renderPath"], source_path.parent),
            "designJson": os.path.relpath(ROOT / row["designPath"], source_path.parent),
            **({"avatarPng": os.path.relpath(ROOT / row["avatarPath"], source_path.parent)} if row.get("avatarPath") else {}),
        })
    target = source_path.parent / "publish-manifest.json"
    value = {"version": 1, "projectRef": PROJECT, "batchId": BATCH,
             "recordDate": "2026-11-03", "posts": posts}
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    return target


def load_manifest(path):
    manifest = json.loads(path.read_text())
    if (manifest.get("projectRef"), manifest.get("batchId"), manifest.get("recordDate")) != (PROJECT, BATCH, "2026-11-03"):
        raise PublishError("This tool is scoped to the reviewed November 3 production batch")
    rows = manifest.get("posts", [])
    if len(rows) != 4 or {r.get("id") for r in rows} != set(AUTHORS):
        raise PublishError("The batch must contain exactly the four authorized posts")
    prepared = []
    for row in rows:
        expected_name, expected_handle, _ = AUTHORS[row["id"]]
        if (row.get("displayName"), row.get("handle")) != (expected_name, expected_handle):
            raise PublishError("Author mapping changed: " + row["id"])
        if len(row.get("caption", "")) > 200 or len(row.get("bio", "")) > 160:
            raise PublishError("Caption or bio is too long")
        original, width, height = checked_png((path.parent / row["originalPng"]).resolve(), original=True)
        snapshot, sw, sh = checked_png((path.parent / row["snapshotPng"]).resolve())
        avatar = None
        if row.get("avatarPng"):
            avatar, aw, ah = checked_png((path.parent / row["avatarPng"]).resolve(), original=True)
            if max(aw, ah) > 1024 or len(avatar) > 3 * 1024 * 1024:
                raise PublishError("Profile photo exceeds the app limits")
        design = json.loads((path.parent / row["designJson"]).read_text())
        if len(canonical(design)) > 128 * 1024 or design.get("version") != 1 or not 1 <= len(design.get("layers", [])) <= 40:
            raise PublishError("Invalid editable document")
        canvas = design["canvas"]
        if abs((canvas["width"] / canvas["height"]) / (sw / sh) - 1) > .003:
            raise PublishError("Snapshot and editable canvas aspect ratios differ")
        prepared.append({**row, "original": original, "snapshot": snapshot, "avatar": avatar,
                         "width": width, "height": height, "design": design})
    fingerprint = digest(canonical({
        "manifest": manifest,
        "media": [{"id": r["id"], "original": digest(r["original"]),
                   "snapshot": digest(r["snapshot"]), "avatar": digest(r["avatar"]) if r["avatar"] else None,
                   "design": digest(canonical(r["design"]))} for r in prepared],
    }))
    return manifest, prepared, fingerprint


def project_keys():
    # Reuse the operator's existing CLI login; never echo command output.
    result = subprocess.run(["supabase", "projects", "api-keys", "--project-ref", PROJECT, "--output", "json"],
                            capture_output=True, text=True, timeout=45)
    if result.returncode:
        raise PublishError("Supabase CLI admin login is unavailable")
    rows = json.loads(result.stdout)
    public = next((r["api_key"] for r in rows if r.get("type") == "publishable" and not r.get("disabled")), None)
    public = public or next((r["api_key"] for r in rows if r.get("name") == "anon" and not r.get("disabled")), None)
    admin = next((r["api_key"] for r in rows if r.get("name") == "service_role" and not r.get("disabled")), None)
    if not public or not admin:
        raise PublishError("Required public/admin credentials are unavailable")
    return public, admin


class Api:
    def __init__(self, api_key, token=None):
        self.key, self.token = api_key, token

    def call(self, method, path, value=None, *, binary=None, raw=False):
        headers = {"apikey": self.key, "Content-Type": "image/png" if binary is not None else "application/json"}
        if self.token:
            headers["Authorization"] = "Bearer " + self.token
        if binary is not None:
            headers.update({"x-upsert": "false", "cache-control": "0"})
        body = binary if binary is not None else canonical(value) if value is not None else None
        request = urllib.request.Request(BASE + path, data=body, method=method, headers=headers)
        context = ssl.create_default_context()
        # python.org's macOS runtime may lack its optional CA symlink. Reuse the
        # host's installed trust bundle; certificate verification stays enabled.
        if not context.get_ca_certs():
            for bundle in ("/etc/ssl/cert.pem", "/opt/homebrew/etc/ca-certificates/cert.pem"):
                if Path(bundle).is_file():
                    context.load_verify_locations(cafile=bundle)
                    break
        try:
            with urllib.request.urlopen(request, timeout=45, context=context) as response:
                data = response.read()
        except urllib.error.HTTPError as error:
            try:
                message = json.loads(error.read())
                code = message.get("code") or message.get("error_code") or message.get("error") or "request_failed"
            except Exception:
                code = "request_failed"
            raise ApiError(error.code, code) from None
        except (urllib.error.URLError, TimeoutError):
            raise PublishError("Network result unknown; rerun the same batch to reconcile") from None
        return data if raw else json.loads(data) if data else None

    def rpc(self, name, params):
        return self.call("POST", "/rest/v1/rpc/" + name, params)

    def social(self, action, payload=None):
        return self.rpc("social_api", {"p_action": action, "p_payload": payload or {}})


def save_private_state(path, value):
    temporary = path.with_suffix(".tmp")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as output:
        os.fchmod(output.fileno(), 0o600)
        output.write(canonical(value))
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, path)


def find_batch_user(admin, email, handle):
    # Read into memory only. Existing identities and addresses are never logged.
    for page in range(1, 101):
        response = admin.call("GET", f"/auth/v1/admin/users?page={page}&per_page=100")
        users = response.get("users", [])
        for user in users:
            if user.get("email", "").lower() == email:
                mark = user.get("app_metadata", {})
                if mark.get("snapfit_content_batch") != BATCH or mark.get("snapfit_content_handle") != handle:
                    raise PublishError("Reserved account alias collision; existing account left unchanged")
                return user["id"]
        if len(users) < 100:
            return None
    raise PublishError("Auth inventory exceeded the bounded lookup")


def immutable_upload(user, bucket, path, data):
    endpoint = "/storage/v1/object/" + bucket + "/" + urllib.parse.quote(path, safe="/")
    try:
        user.call("POST", endpoint, binary=data)
    except ApiError as error:
        if error.status not in (400, 409):
            raise
        previous = user.call("GET", endpoint.replace("/object/", "/object/authenticated/", 1), raw=True)
        if digest(previous) != digest(data):
            raise PublishError("Immutable upload already contains different bytes")


def execute(manifest, rows, fingerprint):
    directory = Path.home() / "Library/Application Support/SnapFit/content-publisher" / PROJECT
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(directory, 0o700)
    state_path = directory / (BATCH + ".json")
    lock_path = directory / (BATCH + ".lock")
    lock_fd = os.open(lock_path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(lock_fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise PublishError("This batch is already running") from None
        if state_path.is_symlink():
            raise PublishError("Refusing a linked credential journal")
        state = json.loads(state_path.read_text()) if state_path.exists() else {"batchId": BATCH, "fingerprint": fingerprint, "authors": {}}
        if state.get("fingerprint") != fingerprint:
            raise PublishError("The started batch differs from the reviewed files; no writes performed")
        public_key, admin_key = project_keys()
        admin, public = Api(admin_key, admin_key), Api(public_key)
        results = []
        for row in rows:
            handle = row["handle"]
            item = state["authors"].get(handle)
            if item is None:
                item = {"email": BATCH + "." + handle.replace(".", "-") + "@content.snapfit.invalid",
                        "password": secrets.token_urlsafe(40), "recordId": str(uuid.uuid4()),
                        "photoId": str(uuid.uuid4()), "avatarId": str(uuid.uuid4()), "requestId": str(uuid.uuid4())}
                state["authors"][handle] = item
                save_private_state(state_path, state)
            # Recover a lost create response before attempting another create.
            uid = find_batch_user(admin, item["email"], handle)
            if item.get("userId") and uid != item["userId"]:
                raise PublishError("Account journal identity changed")
            if uid is None:
                created = admin.call("POST", "/auth/v1/admin/users", {
                    "email": item["email"], "password": item["password"], "email_confirm": True,
                    "app_metadata": {"snapfit_content_batch": BATCH, "snapfit_content_handle": handle},
                })
                uid = created["id"]
            item["userId"] = uid
            save_private_state(state_path, state)
            signed = public.call("POST", "/auth/v1/token?grant_type=password", {"email": item["email"], "password": item["password"]})
            if signed.get("user", {}).get("id") != uid or signed.get("user", {}).get("role") != "authenticated":
                raise PublishError("Ordinary author login did not match the provisioned account")
            user = Api(public_key, signed["access_token"])
            verified = user.call("GET", "/auth/v1/user")
            if verified.get("id") != uid:
                raise PublishError("Author session changed")
            user.social("ensureProfile")
            profile = user.social("upsertProfile", {"displayName": row["displayName"], "handle": handle, "bio": row["bio"]})
            if profile.get("userId") != uid or profile.get("handle") != handle:
                raise PublishError("Public author profile did not match")
            if row.get("avatar"):
                avatar_path = f"{uid}/{item['avatarId']}.png"
                if profile.get("avatarPath") not in (None, avatar_path):
                    raise PublishError("The author profile photo was changed outside this batch")
                if profile.get("avatarPath") != avatar_path:
                    immutable_upload(user, "social-profile-photos", avatar_path, row["avatar"])
                    photo_profile = user.social("setProfilePhoto", {"path": avatar_path})
                    if photo_profile.get("userId") != uid or photo_profile.get("avatarPath") != avatar_path:
                        raise PublishError("The author profile photo did not confirm")
            photo_path = f"{uid}/moments/{item['recordId']}/{item['photoId']}.png"
            quota = user.call("GET", f"/rest/v1/storage_quotas?user_id=eq.{uid}&select=used_bytes,hard_limit_bytes")
            used, hard = (quota[0].get("used_bytes", 0), quota[0].get("hard_limit_bytes", 1073741824)) if quota else (0, 1073741824)
            if used + len(row["original"]) > hard:
                existing = user.call("GET", "/storage/v1/object/authenticated/album-assets/" + photo_path, raw=True)
                if digest(existing) != digest(row["original"]):
                    raise PublishError("Author storage quota is full")
            else:
                immutable_upload(user, "album-assets", photo_path, row["original"])
            record = user.rpc("save_weekly_moment", {
                "p_id": item["recordId"], "p_record_date": manifest["recordDate"], "p_caption": row["caption"],
                "p_photos": [{"id": item["photoId"], "path": photo_path, "width": row["width"], "height": row["height"], "design": row["design"]}],
                "p_expected_revision": 0,
            })
            publication = user.social("momentPublication", {"recordId": item["recordId"]})
            if publication.get("recordRevision") != record["revision"]:
                raise PublishError("Saved record revision changed")
            draft = user.social("beginMomentPublication", {
                "recordId": item["recordId"], "photoId": item["photoId"],
                "expectedRevision": record["revision"], "requestId": item["requestId"],
            })
            if draft["status"] == "draft":
                upload = user.social("publicationUploadPath", {"id": draft["id"], "position": 0})
                expected_path = f"{uid}/{draft['id']}/0.png"
                if upload.get("path") != expected_path:
                    raise PublishError("Publication upload path is not owned by this author")
                if not upload.get("uploaded"):
                    immutable_upload(user, "social-snapshots", expected_path, row["snapshot"])
                published = user.social("finalizePublication", {"id": draft["id"]})
            elif draft["status"] == "published":
                published = user.social("work", {"id": draft["id"]})
            else:
                raise PublishError("Publication state changed; stopped without restoring visibility")
            if published.get("status") != "published" or published.get("author", {}).get("userId") != uid:
                raise PublishError("Publication did not confirm its author and visibility")
            item["workId"] = published["id"]
            item["published"] = True
            save_private_state(state_path, state)
            results.append({"id": row["id"], "handle": handle, "displayName": row["displayName"],
                            "userId": uid, "workId": item["workId"], "status": "published"})
            print(json.dumps(results[-1], ensure_ascii=False), flush=True)
        feed = public.social("feed", {"limit": 30})
        visible = {work["id"] for work in feed.get("items", [])}
        if not all(row["workId"] in visible for row in results):
            raise PublishError("Posts were saved, but the anonymous feed did not confirm every new publication")
        print(json.dumps({"batchId": BATCH, "publicFeedConfirmed": len(results)}, ensure_ascii=False), flush=True)
        return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--prepare-manifest", type=Path)
    parser.add_argument("--execute", action="store_true", help="Perform the already reviewed four-author batch")
    args = parser.parse_args()
    if args.prepare_manifest:
        if args.manifest or args.execute:
            parser.error("Manifest conversion cannot be combined with publication")
        print(prepare_manifest(args.prepare_manifest))
        return
    if not args.manifest:
        parser.error("--manifest is required")
    manifest, rows, fingerprint = load_manifest(args.manifest.resolve())
    if args.execute:
        execute(manifest, rows, fingerprint)
    else:
        print(json.dumps({"mode": "offline-validation", "batchId": BATCH, "fingerprint": fingerprint,
                          "posts": [{"id": r["id"], "handle": r["handle"], "displayName": r["displayName"],
                                     "originalBytes": len(r["original"]), "snapshotBytes": len(r["snapshot"]),
                                     "avatarBytes": len(r["avatar"]) if r["avatar"] else 0,
                                     "editableLayers": len(r["design"]["layers"])} for r in rows]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except PublishError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        # Remote responses and credential-bearing objects must never be echoed.
        print("Publisher stopped: " + type(error).__name__, file=sys.stderr)
        sys.exit(1)
