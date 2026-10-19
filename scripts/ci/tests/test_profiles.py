"""Exercise profile checks with synthetic, temporary signing fixtures."""

import copy
import datetime
import importlib.util
import os
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("profiles", Path(__file__).parents[1] / "prepare-profiles.py")
profiles = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(profiles)


class ProvisioningProfileChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.signing = self.root / "wattage-signing"
        self.signing.mkdir()
        self.app = {
            "UUID": "11111111-1111-1111-1111-111111111111",
            "TeamIdentifier": ["TESTTEAM01"],
            "ExpirationDate": datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) + datetime.timedelta(days=30),
            "ProvisionedDevices": ["synthetic-device"],
            "Entitlements": {
                "application-identifier": f"TESTTEAM01.{profiles.APP_ID}",
                "com.apple.security.application-groups": [profiles.APP_GROUP],
                "get-task-allow": False,
            },
        }
        self.widget = copy.deepcopy(self.app)
        self.widget["UUID"] = "22222222-2222-2222-2222-222222222222"
        self.widget["Entitlements"]["application-identifier"] = f"TESTTEAM01.{profiles.WIDGET_ID}"

    def prepare(self, method="release-testing"):
        for name, value in (("app", self.app), ("widget", self.widget)):
            with (self.signing / f"{name}.plist").open("wb") as destination:
                plistlib.dump(value, destination)
            (self.signing / f"{name}.mobileprovision").write_bytes(b"synthetic profile fixture")
        environment = {
            "RUNNER_TEMP": str(self.root),
            "EXPORT_METHOD": method,
            "GITHUB_ENV": str(self.root / "github.env"),
        }
        with patch.dict(os.environ, environment), patch.object(profiles.Path, "home", return_value=self.root / "home"):
            profiles.prepare()

    def test_registered_device_export_installs_both_profiles_and_maps_bundle_ids(self):
        self.prepare()
        with (self.signing / "ExportOptions.plist").open("rb") as source:
            options = plistlib.load(source)
        self.assertEqual(options["method"], "release-testing")
        self.assertEqual(options["provisioningProfiles"], {
            profiles.APP_ID: self.app["UUID"], profiles.WIDGET_ID: self.widget["UUID"],
        })
        self.assertEqual(len(list((self.root / "home").rglob("*.mobileprovision"))), 4)
        self.assertIn("WATTAGE_WIDGET_PROFILE=22222222-2222-2222-2222-222222222222", (self.root / "github.env").read_text())

    def test_app_store_export_accepts_profiles_without_registered_devices(self):
        del self.app["ProvisionedDevices"]
        del self.widget["ProvisionedDevices"]
        self.prepare("app-store-connect")
        with (self.signing / "ExportOptions.plist").open("rb") as source:
            self.assertEqual(plistlib.load(source)["destination"], "export")

    def test_expired_profile_is_rejected(self):
        self.app["ExpirationDate"] = datetime.datetime(2020, 1, 1)
        with self.assertRaisesRegex(ValueError, "expired"):
            self.prepare()
        self.assertFalse((self.root / "github.env").exists())

    def test_wrong_widget_bundle_is_rejected(self):
        self.widget["Entitlements"]["application-identifier"] = "TESTTEAM01.wrong.bundle"
        with self.assertRaisesRegex(ValueError, "must match"):
            self.prepare()

    def test_missing_widget_app_group_is_rejected(self):
        self.widget["Entitlements"]["com.apple.security.application-groups"] = []
        with self.assertRaisesRegex(ValueError, "must enable"):
            self.prepare()

    def test_different_teams_are_rejected(self):
        self.widget["TeamIdentifier"] = ["OTHERTEAM1"]
        with self.assertRaisesRegex(ValueError, "same team"):
            self.prepare()

    def test_development_profile_is_rejected(self):
        self.app["Entitlements"]["get-task-allow"] = True
        with self.assertRaisesRegex(ValueError, "distribution profile"):
            self.prepare()

    def test_device_profile_cannot_be_exported_to_app_store(self):
        with self.assertRaisesRegex(ValueError, "does not match app-store-connect"):
            self.prepare("app-store-connect")

    def test_enterprise_profile_is_rejected(self):
        self.app["ProvisionsAllDevices"] = True
        with self.assertRaisesRegex(ValueError, "Enterprise"):
            self.prepare()

    def test_unsupported_method_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unsupported"):
            self.prepare("unknown")


if __name__ == "__main__":
    unittest.main()
