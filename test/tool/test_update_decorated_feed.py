"""Read/write boundary and lost-response checks; no network or Flutter build."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid

TOOL = Path(__file__).resolve().parents[2] / "tool"
sys.path.insert(0, str(TOOL))
import update_decorated_feed as update


class Backend:
    def __init__(self):
        self.accounts, self.records, self.works, self.profiles, self.rasters = {}, {}, {}, {}, {}
        self.uploaded, self.requests, self.mutations = set(), {}, []
        self.lose_response = True
        self.rows, self.baseline = [], {}
        for key, (name, handle, bio) in update.publishing.AUTHORS.items():
            uid, rid, pid, wid = [str(uuid.uuid4()) for _ in range(4)]
            account = {"userId": uid, "recordId": rid, "photoId": pid, "workId": wid}
            self.accounts[handle] = account
            profile = {"userId": uid, "handle": handle, "displayName": name, "bio": bio, "avatarPath": uid + "/avatar.png"}
            self.profiles[uid] = profile
            self.records[rid] = {"id": rid, "owner_id": uid, "record_date": "2026-11-03", "caption": "caption",
                "revision": 1, "photos": [{"id": pid, "path": f"{uid}/moments/{rid}/{pid}.png", "width": 1122,
                                           "height": 1402, "design": {"layers": [{"id": "before"}]}}]}
            self.works[wid] = {"id": wid, "author": profile, "status": "published", "caption": "caption"}
            self.rasters[wid] = b"old immutable raster"
            self.rows.append({"id": key, "handle": handle, "caption": "caption", "design": {"canvas": {"width": 4, "height": 5}, "layers": [{"id": "after"}]},
                              "snapshot": b"new immutable raster"})
            self.baseline[key] = {"design": {"layers": [{"id": "before"}]}}

    def preflight(self, manifest, rows, baseline, source, credential_hash, fingerprint, existing=None):
        revision = copy.deepcopy(existing) if existing else {"batchId": update.UPDATE_BATCH, "fingerprint": fingerprint,
            "credentialJournalSha256": credential_hash, "accounts": {}}
        for row in rows:
            account = self.accounts[row["handle"]]
            revision["accounts"].setdefault(row["handle"], {**account, "beforeRevision": 1,
                "oldWorkId": account["workId"], "oldStatusBefore": "published", "requestId": str(uuid.uuid4()),
                "profileBefore": self.profiles[account["userId"]], "oldSnapshotSha256": update.publishing.digest(b"old immutable raster")})
        return revision, {handle: User(self, account) for handle, account in self.accounts.items()}, Public(self)


class User:
    def __init__(self, backend, account):
        self.b, self.a = backend, account

    def rpc(self, name, payload):
        if name == "get_moment_journal":
            return {"records": [copy.deepcopy(self.b.records[self.a["recordId"]])]}
        assert name == "save_weekly_moment"
        self.b.mutations.append(name)
        record = self.b.records[self.a["recordId"]]
        assert payload["p_id"] == record["id"] and payload["p_caption"] == record["caption"]
        assert payload["p_photos"][0]["path"] == record["photos"][0]["path"]
        assert payload["p_expected_revision"] == 1
        if record["photos"] != payload["p_photos"]:
            assert record["revision"] == 1
            record["photos"] = copy.deepcopy(payload["p_photos"])
            record["revision"] += 1
            self.b.works[self.a["workId"]]["status"] = "private"
        return copy.deepcopy(record)

    def social(self, action, payload):
        if action == "profile":
            return self.b.profiles[self.a["userId"]]
        if action == "work":
            work = self.b.works[payload["id"]]
            assert work["author"]["userId"] == self.a["userId"]
            return work
        if action == "beginMomentPublication":
            assert payload["recordId"] == self.a["recordId"] and payload["photoId"] == self.a["photoId"]
            assert payload["expectedRevision"] == 2
            if payload["requestId"] not in self.b.requests:
                wid = str(uuid.uuid4())
                self.b.requests[payload["requestId"]] = wid
                self.b.works[wid] = {"id": wid, "author": self.b.profiles[self.a["userId"]], "status": "draft", "caption": "caption", "aspectRatio": .8, "likeCount": 0, "commentCount": 0}
            return self.b.works[self.b.requests[payload["requestId"]]]
        work = self.b.works[payload["id"]]
        if action == "publicationUploadPath":
            path = f"{self.a['userId']}/{work['id']}/0.png"
            return {"path": path, "uploaded": path in self.b.uploaded}
        assert action == "finalizePublication"
        self.b.mutations.append(action)
        work["status"] = "published"
        if self.b.lose_response:
            self.b.lose_response = False
            raise update.publishing.PublishError("Lost finalization response")
        return work


class Public:
    def __init__(self, backend):
        self.b = backend

    def social(self, action, payload):
        if action == "feed":
            return {"items": [w for w in self.b.works.values() if w["status"] == "published"]}
        assert action == "work"
        work = self.b.works[payload["id"]]
        return work if work["status"] == "published" else None


class UpdateTests(unittest.TestCase):
    def test_resume_keeps_four_authors_records_and_original_journal_and_no_duplicate_publications(self):
        backend = Backend()
        profiles_before = copy.deepcopy(backend.profiles)
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            credential = directory / "original.json"
            credential.write_bytes(b"existing credentials must remain byte-identical")
            before = credential.read_bytes()
            credential_hash = update.publishing.digest(before)
            def upload(user, bucket, path, data):
                self.assertEqual(bucket, "social-snapshots")
                backend.uploaded.add(path)
                backend.rasters[path.split("/")[1]] = data
            with patch.object(update, "credentials", return_value=({"authors": backend.accounts}, credential_hash)), \
                 patch.object(update, "credential_path", return_value=credential), \
                 patch.object(update, "state_directory", return_value=directory), \
                 patch.object(update, "preflight", side_effect=backend.preflight), \
                 patch.object(update.publishing, "immutable_upload", side_effect=upload), \
                 patch.object(update.verification, "media", side_effect=lambda user, work: backend.rasters[work["id"]]), \
                 contextlib.redirect_stdout(io.StringIO()):
                args = ({"recordDate": "2026-11-03"}, backend.rows, "reviewed", backend.baseline, directory / "manifest.json")
                with self.assertRaisesRegex(update.publishing.PublishError, "Lost finalization"):
                    update.execute(*args)
                report_path = update.execute(*args)
                update.execute(*args)
            self.assertEqual(credential.read_bytes(), before)
            self.assertEqual(len(backend.accounts), 4)
            self.assertEqual(len(backend.records), 4)
            self.assertEqual(len(backend.requests), 4)
            self.assertEqual(len(backend.works), 8)
            self.assertEqual(sum(w["status"] == "published" for w in backend.works.values()), 4)
            self.assertEqual(sum(w["status"] == "private" for w in backend.works.values()), 4)
            self.assertEqual(backend.profiles, profiles_before)
            self.assertTrue(all(r["revision"] == 2 for r in backend.records.values()))
            self.assertEqual(set(backend.mutations), {"save_weekly_moment", "finalizePublication"})
            report = json.loads(report_path.read_text())
            self.assertTrue(report["originalCredentialJournalUnchanged"])
            self.assertEqual(report["newAccountsCreated"], 0)
            self.assertTrue(all(p["oldWorkAnonymousAccessRevoked"] and p["historicalSnapshotPreserved"] for p in report["posts"]))

    def test_default_mode_is_offline(self):
        backend = Backend()
        with patch.object(update.sys, "argv", ["updater", "--manifest", "unused"]), \
             patch.object(update, "load", return_value=({}, backend.rows, "reviewed", backend.baseline)), \
             patch.object(update, "credentials") as credentials, patch.object(update, "preflight") as preflight, \
             patch.object(update, "execute") as execute, contextlib.redirect_stdout(io.StringIO()):
            update.main()
        credentials.assert_not_called()
        preflight.assert_not_called()
        execute.assert_not_called()

    def test_unavailable_frame_stops_before_any_author_login_or_record_edit(self):
        class ReadOnlyCatalog:
            def call(self, method, path):
                self_method = method
                assert self_method == "GET" and path.startswith("/rest/v1/point_shop_products?")
                return []
        row = {"design": {"layers": [{"type": "IMAGE", "payload": {"imageBackground": "notRegistered"}}]}}
        with patch.object(update, "public_key", return_value="public"), \
             patch.object(update.publishing, "Api", return_value=ReadOnlyCatalog()):
            with self.assertRaisesRegex(update.publishing.PublishError, "active and free"):
                update.preflight({}, [row], {}, {}, "credential-hash", "reviewed")


if __name__ == "__main__":
    unittest.main()
