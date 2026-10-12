import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest

MODULE = Path(__file__).with_name("prepare_session_identity.py")
spec = importlib.util.spec_from_file_location("prepare_test_identity", MODULE)
producer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(producer)


class PrivateSessionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sandbox-test-identity-")
        self.root = Path(self.temp.name).resolve()
        self.project = self.root / "project"
        self.project.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def test_distinct_sessions_have_random_private_values(self):
        one = producer.create(self.root / "one", self.project)
        two = producer.create(self.root / "two", self.project)
        a, b = json.loads(one.read_text()), json.loads(two.read_text())
        self.assertTrue(a["resume_secret"] != b["resume_secret"], "Distinct sessions must use distinct credentials")
        self.assertTrue(a["session_id"] != b["session_id"], "Distinct sessions must use distinct identifiers")
        self.assertEqual(len(a["resume_secret"]), 39)
        self.assertEqual(stat.S_IMODE(one.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(one.parent.stat().st_mode), 0o700)
        self.assertTrue(a == json.loads(one.read_text()), "Session contents must remain stable")

    def test_existing_session_is_not_overwritten(self):
        path = producer.create(self.root / "existing", self.project)
        before = path.read_bytes()
        with self.assertRaises(ValueError):
            producer.create(path.parent, self.project)
        self.assertTrue(before == path.read_bytes(), "Existing session must remain unchanged")

    def test_project_tree_rejected(self):
        with self.assertRaises(ValueError):
            producer.create(self.project / "private", self.project)
        self.assertFalse((self.project / "private").exists())

    def test_symbolic_parent_rejected(self):
        target = self.root / "target"
        target.mkdir()
        alias = self.root / "alias"
        alias.symlink_to(target, target_is_directory=True)
        with self.assertRaises(ValueError):
            producer.create(alias / "private", self.project)
        self.assertFalse((target / "private").exists())

    def test_missing_parent_rejected(self):
        with self.assertRaises(ValueError):
            producer.create(self.root / "missing" / "private", self.project)


if __name__ == "__main__":
    unittest.main()
