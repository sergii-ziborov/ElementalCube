#!/usr/bin/env python3
"""Apply the reviewed local card to an existing ElementalCube app record.

Default mode only validates text. --apply writes editable metadata; it never
submits an App Store release or invites testers.
"""
import argparse
import json
from pathlib import Path
from asc import BUNDLE, ROOT, call

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--apply",action="store_true")
parser.add_argument("--build",help="Processed TestFlight build number to localize")
args=parser.parse_args()
metadata=json.loads((ROOT/"docs/app-store/metadata.json").read_text())
limits={"subtitle":30,"promotionalText":170,"keywords":100,"description":4000,"betaDescription":4000,"whatToTest":4000}
for locale,values in metadata["localizations"].items():
    for field,limit in limits.items():
        if len(values[field])>limit: raise SystemExit(f"{locale} {field} exceeds {limit} characters")
if not args.apply:
    print("Validated Russian and English card. Use --apply after creating the app record.")
    raise SystemExit(0)

apps=call("GET","/v1/apps",{"filter[bundleId]":BUNDLE})["data"]
if len(apps)!=1: raise SystemExit("Create the ElementalCube app record in App Store Connect first.")
app=apps[0]["id"]

def upsert(resource,parent_type,parent_id,parent_relation,localized):
    existing=call("GET",f"/v1/{parent_type}/{parent_id}/{resource}",{"limit":200})["data"]
    for locale,attributes in localized.items():
        match=next((r for r in existing if r["attributes"]["locale"]==locale),None)
        if match:
            call("PATCH",f"/v1/{resource}/{match['id']}",body={"data":{
                "type":resource,"id":match["id"],"attributes":attributes}})
        else:
            call("POST",f"/v1/{resource}",body={"data":{"type":resource,
                "attributes":dict(attributes,locale=locale),"relationships":{
                    parent_relation:{"data":{"type":parent_type,"id":parent_id}}}}})
        print(f"Saved {resource}: {locale}")

upsert("betaAppLocalizations","apps",app,"app",{
    locale:{"description":v["betaDescription"],"feedbackEmail":metadata["feedbackEmail"],
        "marketingUrl":metadata["marketingUrl"],"privacyPolicyUrl":metadata["privacyPolicyUrl"]}
    for locale,v in metadata["localizations"].items()})

infos=call("GET",f"/v1/apps/{app}/appInfos")["data"]
editable={"PREPARE_FOR_SUBMISSION","DEVELOPER_REJECTED","REJECTED"}
infos=[i for i in infos if i["attributes"].get("appStoreState") in editable]
if len(infos)!=1: raise SystemExit("Expected one editable app information record; review App Store Connect state.")
info=infos[0]["id"]
call("PATCH",f"/v1/appInfos/{info}",body={"data":{"type":"appInfos","id":info,
    "relationships":{
        "primaryCategory":{"data":{"type":"appCategories","id":"GAMES"}},
        "primarySubcategoryOne":{"data":{"type":"appCategories","id":"GAMES_PUZZLE"}},
        "primarySubcategoryTwo":{"data":{"type":"appCategories","id":"GAMES_ADVENTURE"}}}}})
upsert("appInfoLocalizations","appInfos",info,"appInfo",{
    locale:{"name":metadata["name"],"subtitle":v["subtitle"],"privacyPolicyUrl":metadata["privacyPolicyUrl"]}
    for locale,v in metadata["localizations"].items()})

versions=call("GET",f"/v1/apps/{app}/appStoreVersions",{"filter[platform]":"IOS"})["data"]
versions=[v for v in versions if v["attributes"].get("appStoreState") in editable]
if len(versions)!=1: raise SystemExit("Expected one editable iOS version; review App Store Connect state.")
version=versions[0]["id"]
call("PATCH",f"/v1/appStoreVersions/{version}",body={"data":{"type":"appStoreVersions","id":version,
    "attributes":{"versionString":metadata["version"],"copyright":metadata["copyright"],"releaseType":"MANUAL"}}})
upsert("appStoreVersionLocalizations","appStoreVersions",version,"appStoreVersion",{
    locale:{"description":v["description"],"keywords":v["keywords"],"promotionalText":v["promotionalText"],
        "supportUrl":metadata["supportUrl"],"marketingUrl":metadata["marketingUrl"]}
    for locale,v in metadata["localizations"].items()})

if args.build:
    builds=call("GET","/v1/builds",{"filter[app]":app,"filter[version]":args.build})["data"]
    if len(builds)!=1 or builds[0]["attributes"]["processingState"]!="VALID":
        raise SystemExit("Build must finish Apple processing before adding What to Test.")
    upsert("betaBuildLocalizations","builds",builds[0]["id"],"build",{
        locale:{"whatsNew":v["whatToTest"]} for locale,v in metadata["localizations"].items()})
print(f"Card saved: https://appstoreconnect.apple.com/apps/{app}/testflight")
