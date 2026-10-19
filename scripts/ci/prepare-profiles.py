#!/usr/bin/env python3
"""Validate app/widget distribution profiles and prepare manual Xcode export."""

import datetime
import os
from pathlib import Path
import plistlib
import re
import shutil

APP_ID = "dev.reom.WattageManage"
WIDGET_ID = "dev.reom.WattageManage.Widgets"
APP_GROUP = "group.dev.reom.WattageManage"


def prepare():
    signing_dir = Path(os.environ["RUNNER_TEMP"]) / "wattage-signing"
    method = os.environ["EXPORT_METHOD"]
    if method not in ("release-testing", "app-store-connect"):
        raise ValueError("Unsupported export method")

    profiles = []
    for basename, bundle_id in (("app", APP_ID), ("widget", WIDGET_ID)):
        with (signing_dir / f"{basename}.plist").open("rb") as source:
            profile = plistlib.load(source)
        uuid = profile["UUID"]
        if not re.fullmatch(r"[0-9a-fA-F-]{36}", uuid):
            raise ValueError(f"Invalid {basename} profile UUID")
        expiry = profile["ExpirationDate"].replace(tzinfo=datetime.timezone.utc)
        if expiry <= datetime.datetime.now(datetime.timezone.utc):
            raise ValueError(f"The {basename} provisioning profile has expired")
        team_id = profile["TeamIdentifier"][0]
        if not re.fullmatch(r"[A-Z0-9]{10}", team_id):
            raise ValueError(f"Invalid {basename} Apple Developer team identifier")
        entitlements = profile["Entitlements"]
        app_identifier = entitlements.get("application-identifier", "")
        if app_identifier.partition(".")[2] != bundle_id:
            raise ValueError(f"The {basename} profile must match {bundle_id} exactly")
        if APP_GROUP not in entitlements.get("com.apple.security.application-groups", []):
            raise ValueError(f"The {basename} profile must enable {APP_GROUP}")
        if entitlements.get("get-task-allow", False):
            raise ValueError(f"The {basename} profile must be a distribution profile")
        if profile.get("ProvisionsAllDevices", False):
            raise ValueError("Enterprise profiles are not supported by this workflow")
        has_devices = bool(profile.get("ProvisionedDevices"))
        if (method == "release-testing") != has_devices:
            raise ValueError(f"The {basename} profile does not match {method}")
        profiles.append((basename, bundle_id, uuid, team_id))

    if profiles[0][3] != profiles[1][3]:
        raise ValueError("App and widget provisioning profiles must belong to the same team")

    options_path = signing_dir / "ExportOptions.plist"
    options = {
        "method": method,
        "destination": "export",
        "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "teamID": profiles[0][3],
        "provisioningProfiles": {bundle: uuid for _, bundle, uuid, _ in profiles},
        "manageAppVersionAndBuildNumber": False,
        "stripSwiftSymbols": True,
    }
    with options_path.open("wb") as destination:
        plistlib.dump(options, destination)

    # Record cleanup identifiers before installing anything in the home directory.
    with Path(os.environ["GITHUB_ENV"]).open("a") as environment:
        environment.write(f"WATTAGE_TEAM_ID={profiles[0][3]}\n")
        environment.write(f"WATTAGE_APP_PROFILE={profiles[0][2]}\n")
        environment.write(f"WATTAGE_WIDGET_PROFILE={profiles[1][2]}\n")
        environment.write(f"EXPORT_OPTIONS_PATH={options_path}\n")

    # Xcode 16+ uses UserData; also install in the traditional location.
    for directory in (
        Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
        Path.home() / "Library/MobileDevice/Provisioning Profiles",
    ):
        directory.mkdir(parents=True, exist_ok=True)
        for basename, _, uuid, _ in profiles:
            shutil.copyfile(signing_dir / f"{basename}.mobileprovision", directory / f"{uuid}.mobileprovision")
    print("Validated and installed app and widget distribution profiles.")


if __name__ == "__main__":
    try:
        prepare()
    except (KeyError, ValueError, OSError, plistlib.InvalidFileException) as error:
        raise SystemExit(f"Signing configuration error: {error}") from None
