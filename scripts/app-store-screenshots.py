#!/usr/bin/env python3
"""Validate native screenshots; --apply uploads them to the editable Apple card.

Manual helper, without CI/CD. Existing assets are retained unless --replace-earlier removes our older alpha 4 set after successful delivery.
Credentials and temporary upload URLs are never printed or saved.
"""
import argparse
import hashlib
import ssl
import struct
import time
import urllib.error
import urllib.parse
import urllib.request

from asc import BUNDLE, ROOT, call

GALLERIES = {
    "skills8": {
        "APP_IPHONE_61": [(f"iphone-{scene}.png", (1206,2622)) for scene in ("skills","fire-skills","gesture","ice")],
    },
    "alpha4": {
        "APP_IPHONE_61": [(f"iphone-{form}.png", (2622,1206)) for form in ("ice","water","air","stone","fire")],
        "APP_IPAD_PRO_3GEN_129": [("ipad-13-ice.png", (2064,2752))],
    },
    "gestures7": {
        "APP_IPHONE_61": [(f"iphone-{scene}.png", (1206,2622)) for scene in ("gesture","skills","equipment","ice")],
        "APP_IPAD_PRO_3GEN_129": [(f"ipad-13-{scene}.png", (2064,2752)) for scene in ("skills","ice")],
    },
    "physics6": {
        "APP_IPHONE_61": [(f"iphone-{scene}.png", (1206,2622)) for scene in ("ice","crate","bridge","ability")],
        "APP_IPAD_PRO_3GEN_129": [("ipad-13-ice.png", (2064,2752))],
    },
}
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"}


def validate(gallery):
    for files in GALLERIES[gallery].values():
        for name, size in files:
            data = (ROOT / "Previews" / gallery / name).read_bytes()
            if data[:8] != b"\x89PNG\r\n\x1a\n":
                raise SystemExit(f"Invalid PNG: {name}")
            width, height, depth, color = struct.unpack(">IIBB", data[16:26])
            if (width, height) != size or depth != 8 or color != 2:
                raise SystemExit(f"Expected original-size RGB PNG without alpha: {name}")
    print(f"Validated original {gallery} screenshots for the declared display sizes.", flush=True)


def upload(screenshot, data, name):
    attrs = screenshot["attributes"]
    state = attrs["assetDeliveryState"]["state"]
    checksum = hashlib.md5(data).hexdigest()
    if attrs.get("sourceFileChecksum") not in (None, checksum):
        raise SystemExit(f"Existing screenshot differs; review the card manually: {name}")
    if state == "FAILED":
        raise SystemExit(f"Apple rejected an existing asset; review the card: {name}")
    if state == "AWAITING_UPLOAD":
        operations = attrs.get("uploadOperations") or []
        if not operations:
            raise SystemExit(f"No upload operations available: {name}")
        context = ssl.create_default_context(cafile="/etc/ssl/cert.pem")
        for op in operations:
            if urllib.parse.urlparse(op["url"]).scheme != "https":
                raise SystemExit("Apple returned a non-HTTPS upload operation")
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            if len(chunk) != op["length"]:
                raise SystemExit(f"Invalid upload byte range: {name}")
            request = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                headers={h["name"]: h["value"] for h in op["requestHeaders"]})
            try:
                with urllib.request.urlopen(request, context=context, timeout=45) as response:
                    response.read()
            except (urllib.error.URLError, TimeoutError):
                # The exception's URL may contain an expiring upload credential.
                raise SystemExit(f"Asset transfer failed; retry or review the card: {name}") from None
        call("PATCH", f"/v1/appScreenshots/{screenshot['id']}", body={"data": {
            "type": "appScreenshots", "id": screenshot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": checksum}}})


def apply(gallery, replace_earlier=False):
    apps = call("GET", "/v1/apps", {"filter[bundleId]": BUNDLE})["data"]
    if len(apps) != 1:
        raise SystemExit("Expected the existing ElementalCube app card")
    app = apps[0]["id"]
    versions = call("GET", f"/v1/apps/{app}/appStoreVersions",
                    {"filter[platform]": "IOS"})["data"]
    versions = [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE]
    if len(versions) != 1:
        raise SystemExit("Expected one editable iOS version")
    version = versions[0]["id"]
    locales = call("GET", f"/v1/appStoreVersions/{version}/appStoreVersionLocalizations",
                   {"limit": 200})["data"]
    locales = [loc for loc in locales if loc["attributes"]["locale"] in ("ru", "en-US")]
    if len(locales) != 2:
        raise SystemExit("Apply Russian and English metadata before screenshots")
    pending = []
    superseded = []
    for locale in locales:
        language = locale["attributes"]["locale"]
        sets = call("GET", f"/v1/appStoreVersionLocalizations/{locale['id']}/appScreenshotSets",
                    {"limit": 200})["data"]
        for display, files in GALLERIES[gallery].items():
            screenshot_set = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == display), None)
            if screenshot_set is None:
                screenshot_set = call("POST", "/v1/appScreenshotSets", body={"data": {
                    "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display},
                    "relationships": {"appStoreVersionLocalization": {"data": {
                        "type": "appStoreVersionLocalizations", "id": locale["id"]}}}}})["data"]
            existing = call("GET", f"/v1/appScreenshotSets/{screenshot_set['id']}/appScreenshots",
                            {"limit": 50})["data"]
            if replace_earlier and gallery != "alpha4":
                order=("alpha4","physics6","gestures7","skills8")
                older=order[:order.index(gallery)]
                old_names={n if old=="alpha4" else old+"-"+n for old in older for n,_ in GALLERIES[old].get(display,[])}
                superseded.extend(asset["id"] for asset in existing if asset["attributes"]["fileName"] in old_names)
            for name, _ in files:
                remote_name=name if gallery=="alpha4" else gallery+"-"+name
                data = (ROOT / "Previews" / gallery / name).read_bytes()
                screenshot = next((s for s in existing if s["attributes"]["fileName"] == remote_name), None)
                if screenshot is None:
                    if len(existing) >= 10:
                        raise SystemExit(f"Screenshot set is full: {language} {display}")
                    screenshot = call("POST", "/v1/appScreenshots", body={"data": {
                        "type": "appScreenshots", "attributes": {"fileName": remote_name, "fileSize": len(data)},
                        "relationships": {"appScreenshotSet": {"data": {
                            "type": "appScreenshotSets", "id": screenshot_set["id"]}}}}})["data"]
                    existing.append(screenshot)
                upload(screenshot, data, name)
                pending.append((screenshot["id"], language, name))
                print(f"Uploaded or retained: {language} {name}", flush=True)
    for _ in range(6):
        incomplete = []
        for identity, language, name in pending:
            asset = call("GET", f"/v1/appScreenshots/{identity}")["data"]
            state = asset["attributes"]["assetDeliveryState"]["state"]
            if state == "FAILED":
                raise SystemExit(f"Apple asset processing failed: {language} {name}")
            if state != "COMPLETE":
                incomplete.append((identity, language, name))
        if not incomplete:
            print("Apple confirmed all screenshots COMPLETE.", flush=True)
            for identity in superseded:
                call("DELETE", f"/v1/appScreenshots/{identity}")
            if superseded:
                print(f"Replaced {len(superseded)} earlier owned screenshots after confirming the new set.", flush=True)
            return
        pending = incomplete
        time.sleep(5)
    raise SystemExit("Some assets are still processing; rerun to verify without duplicates.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--gallery",choices=GALLERIES,default="skills8")
    parser.add_argument("--replace-earlier",action="store_true",help="Remove our known earlier assets only after the new gallery is COMPLETE")
    args = parser.parse_args()
    validate(args.gallery)
    if args.apply:
        apply(args.gallery,args.replace_earlier)
