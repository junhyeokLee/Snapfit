"""No-network checks for the narrowly scoped content publishing helper."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import uuid

MODULE = Path(__file__).resolve().parents[2] / "tool/publish_decorated_feed.py"
spec = importlib.util.spec_from_file_location("content_publisher", MODULE)
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class Backend:
    def __init__(self):
        self.users = [{"id": str(uuid.uuid4()), "email": "existing@example.invalid", "app_metadata": {"untouched": True}}]
        self.passwords, self.profiles, self.objects, self.records, self.works = {}, {}, {}, {}, {}
        self.calls = []
        self.lose_finalize_response = True


class FakeApi:
    def __init__(self, backend, key, token=None):
        self.backend, self.key, self.token = backend, key, token
        self.uid = token.removeprefix("token:") if token and token.startswith("token:") else None

    def call(self, method, path, value=None, *, binary=None, raw=False):
        b = self.backend
        b.calls.append((self.key, method, path))
        if self.key == "admin":
            if method == "GET" and path.startswith("/auth/v1/admin/users?"):
                return {"users": b.users}
            if method == "POST" and path == "/auth/v1/admin/users":
                assert value["email_confirm"] is True
                assert value["email"].endswith("@content.snapfit.invalid")
                user = {"id": str(uuid.uuid4()), "email": value["email"], "app_metadata": value["app_metadata"]}
                b.users.append(user)
                b.passwords[user["id"]] = value["password"]
                return user
            raise AssertionError("Admin credential used outside account provisioning")
        if path == "/auth/v1/token?grant_type=password":
            user = next(x for x in b.users if x["email"] == value["email"])
            assert value["password"] == b.passwords[user["id"]]
            return {"user": {"id": user["id"], "role": "authenticated"}, "access_token": "token:" + user["id"]}
        assert self.uid
        if path == "/auth/v1/user":
            return {"id": self.uid}
        if path.startswith("/rest/v1/storage_quotas?"):
            assert "eq." + self.uid in path
            return []
        if path.startswith("/storage/v1/object/"):
            assert "/" + self.uid + "/" in path
            normalized = path.replace("/object/authenticated/", "/object/")
            if method == "POST":
                if normalized in b.objects:
                    raise publisher.ApiError(409, "Duplicate")
                b.objects[normalized] = binary
                return {"Key": normalized}
            assert "/object/authenticated/" in path
            return b.objects[normalized]
        raise AssertionError(path)

    def rpc(self, name, params):
        assert name == "save_weekly_moment"
        assert params["p_expected_revision"] == 0
        assert params["p_photos"][0]["path"].startswith(self.uid + "/moments/")
        self.backend.records[params["p_id"]] = params
        return {"revision": 1}

    def social(self, action, payload=None):
        payload = payload or {}
        b = self.backend
        if action == "feed":
            assert self.key == "public" and self.uid is None
            return {"items": [w for w in b.works.values() if w["status"] == "published"]}
        assert self.uid and self.key == "public"
        if action == "ensureProfile":
            return b.profiles.setdefault(self.uid, {"userId": self.uid})
        if action == "upsertProfile":
            b.profiles[self.uid].update(payload)
            return b.profiles[self.uid]
        if action == "setProfilePhoto":
            b.profiles[self.uid]["avatarPath"] = payload["path"]
            return b.profiles[self.uid]
        if action == "momentPublication":
            assert payload["recordId"] in b.records
            return {"recordRevision": 1}
        if action == "beginMomentPublication":
            request_id = payload["requestId"]
            if request_id not in b.works:
                b.works[request_id] = {"id": str(uuid.uuid4()), "status": "draft", "author": {"userId": self.uid}}
            return b.works[request_id]
        work = next(w for w in b.works.values() if w["id"] == payload["id"])
        assert work["author"]["userId"] == self.uid
        if action == "publicationUploadPath":
            path = f"{self.uid}/{work['id']}/0.png"
            return {"path": path, "uploaded": "/storage/v1/object/social-snapshots/" + path in b.objects}
        if action == "finalizePublication":
            work["status"] = "published"
            if b.lose_finalize_response:
                b.lose_finalize_response = False
                raise publisher.PublishError("Lost response after commit")
            return work
        if action == "work":
            return work
        raise AssertionError(action)


class PublisherTests(unittest.TestCase):
    def rows(self):
        return [{"id": key, "displayName": name, "handle": handle, "bio": bio, "caption": "today",
                 "original": b"prepared-original", "snapshot": b"rendered-snapshot", "avatar": b"prepared-avatar",
                 "width": 1122, "height": 1402, "design": {"version": 1, "layers": []}}
                for key, (name, handle, bio) in publisher.AUTHORS.items()]

    def test_lost_publish_response_recovers_without_duplicate_accounts_or_posts(self):
        backend, output = Backend(), io.StringIO()
        original_user = dict(backend.users[0])
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(publisher.Path, "home", return_value=Path(directory)), \
                 patch.object(publisher, "project_keys", return_value=("public", "admin")), \
                 patch.object(publisher, "Api", side_effect=lambda key, token=None: FakeApi(backend, key, token)), \
                 contextlib.redirect_stdout(output):
                with self.assertRaisesRegex(publisher.PublishError, "Lost response"):
                    publisher.execute({"recordDate": "2026-11-03"}, self.rows(), "reviewed")
                result = publisher.execute({"recordDate": "2026-11-03"}, self.rows(), "reviewed")
                publisher.execute({"recordDate": "2026-11-03"}, self.rows(), "reviewed")
            state_path = next(Path(directory).rglob(publisher.BATCH + ".json"))
            state = json.loads(state_path.read_text())
            self.assertEqual(state_path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(state_path.parent.stat().st_mode & 0o777, 0o700)
            for author in state["authors"].values():
                self.assertNotIn(author["password"], output.getvalue())
                self.assertNotIn(author["email"], output.getvalue())
        self.assertEqual(len(result), 4)
        self.assertEqual(len(backend.users), 5)
        self.assertEqual(len(backend.works), 4)
        self.assertEqual(len(backend.records), 4)
        self.assertEqual(len(backend.objects), 12)
        self.assertEqual(backend.users[0], original_user)
        self.assertTrue(all(w["status"] == "published" for w in backend.works.values()))

    def test_alias_collision_does_not_adopt_an_existing_account(self):
        backend = Backend()
        backend.users[0]["email"] = publisher.BATCH + ".bori-walks@content.snapfit.invalid"
        api = FakeApi(backend, "admin", "admin")
        with self.assertRaisesRegex(publisher.PublishError, "collision"):
            publisher.find_batch_user(api, backend.users[0]["email"], "bori.walks")
        self.assertEqual(len(backend.users), 1)
        self.assertTrue(all(method == "GET" for _, method, _ in backend.calls))

    def test_default_mode_never_fetches_admin_credentials_or_publishes(self):
        with patch.object(publisher.sys, "argv", [str(MODULE), "--manifest", "unused.json"]), \
             patch.object(publisher, "load_manifest", return_value=({}, self.rows(), "reviewed")), \
             patch.object(publisher, "project_keys") as keys, patch.object(publisher, "execute") as execute, \
             contextlib.redirect_stdout(io.StringIO()):
            publisher.main()
        keys.assert_not_called()
        execute.assert_not_called()


if __name__ == "__main__":
    unittest.main()
