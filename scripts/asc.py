#!/usr/bin/env python3
"""Local App Store Connect client. Credentials stay outside the repository."""
import argparse
import base64
import json
import os
from pathlib import Path
import shlex
import ssl
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = "com.weavatrix.elementalcube"
PROFILE = "ElementalCube App Store"
IDENTITY = "Apple Distribution: Serhii Ziborov (XMS5ZC28UJ)"

def credentials():
    path = Path(os.environ.get("ASC_ENV_FILE", Path.home()/".private_keys/appstoreconnect.env"))
    if path.is_file():
        for line in path.read_text().splitlines():
            line = line.strip().removeprefix("export ")
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            if key.strip() in {"ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH"}:
                os.environ.setdefault(key.strip(), shlex.split(value)[0])
    for key in ("ASC_KEY_ID", "ASC_ISSUER_ID"):
        if not os.environ.get(key):
            raise SystemExit(f"Set {key} in the environment or ASC_ENV_FILE")
    return (os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"],
        Path(os.environ.get("ASC_KEY_PATH", Path.home()/f".private_keys/AuthKey_{os.environ['ASC_KEY_ID']}.p8")))

def token():
    key_id, issuer, path = credentials()
    encode = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=").decode()
    now = int(time.time())
    parts = [{"alg":"ES256", "kid":key_id, "typ":"JWT"},
        {"iss":issuer, "iat":now, "exp":now+900, "aud":"appstoreconnect-v1"}]
    message = ".".join(encode(json.dumps(p,separators=(",",":")).encode()) for p in parts)
    der = subprocess.run(["openssl","dgst","-sha256","-sign",str(path)],
        input=message.encode(),capture_output=True,check=True).stdout
    # ES256 signatures from OpenSSL are DER INTEGERs; JWT requires fixed-width r || s.
    def element(data, offset):
        tag, length = data[offset], data[offset+1]; offset += 2
        if length & 0x80:
            count = length & 0x7f; length = int.from_bytes(data[offset:offset+count],"big"); offset += count
        return tag, data[offset:offset+length], offset+length
    tag, body, _ = element(der,0)
    if tag != 0x30: raise ValueError("Invalid signature sequence")
    values, offset = [], 0
    while offset < len(body):
        tag, value, offset = element(body,offset)
        if tag != 0x02: raise ValueError("Invalid signature integer")
        values.append(int.from_bytes(value,"big").to_bytes(32,"big"))
    if len(values) != 2: raise ValueError("Invalid signature length")
    return message+"."+encode(b"".join(values))

def call(method, path, query=None, body=None):
    if not path.startswith("/v1/"): raise ValueError("Only App Store Connect v1 endpoints are supported")
    url = "https://api.appstoreconnect.apple.com"+path
    if query: url += "?"+urllib.parse.urlencode(query)
    request = urllib.request.Request(url,method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization":"Bearer "+token(),"Content-Type":"application/json"})
    ca = Path("/etc/ssl/cert.pem")
    context = ssl.create_default_context(cafile=str(ca) if ca.is_file() else None)
    try:
        with urllib.request.urlopen(request,context=context,timeout=45) as response:
            content=response.read(); return json.loads(content) if content else {}
    except urllib.error.HTTPError as error:
        raise SystemExit(f"{method} {path}: HTTP {error.code}\n{error.read().decode()}") from None

def prepare_signing():
    bundles=call("GET","/v1/bundleIds",{"filter[identifier]":BUNDLE})["data"]
    bundle=next((b for b in bundles if b["attributes"]["identifier"] == BUNDLE),None)
    if not bundle:
        bundle=call("POST","/v1/bundleIds",body={"data":{"type":"bundleIds",
            "attributes":{"identifier":BUNDLE,"name":"ElementalCube","platform":"IOS"}}})["data"]
    pem=subprocess.run(["security","find-certificate","-c",IDENTITY,"-p"],capture_output=True,check=True).stdout
    serial=subprocess.run(["openssl","x509","-noout","-serial"],input=pem,capture_output=True,check=True).stdout.decode().strip().split("=",1)[1].lstrip("0")
    certs=call("GET","/v1/certificates",{"filter[certificateType]":"DISTRIBUTION"})["data"]
    cert=next(c for c in certs if c["attributes"]["serialNumber"].upper().lstrip("0")==serial.upper())
    profiles=call("GET",f"/v1/bundleIds/{bundle['id']}/profiles",{"limit":200})["data"]
    profile=None
    for p in profiles:
        if p["attributes"]["profileType"] == "IOS_APP_STORE" and p["attributes"]["profileState"] == "ACTIVE":
            ids=call("GET",f"/v1/profiles/{p['id']}/certificates")["data"]
            if any(c["id"]==cert["id"] for c in ids):
                profile=call("GET",f"/v1/profiles/{p['id']}")["data"]; break
    if profile is None:
        profile=call("POST","/v1/profiles",body={"data":{"type":"profiles",
            "attributes":{"name":PROFILE,"profileType":"IOS_APP_STORE"},
            "relationships":{"bundleId":{"data":{"type":"bundleIds","id":bundle["id"]}},
                "certificates":{"data":[{"type":"certificates","id":cert["id"]}]}}}})["data"]
    attrs=profile["attributes"]
    destination=Path.home()/"Library/Developer/Xcode/UserData/Provisioning Profiles"/(attrs["uuid"]+".mobileprovision")
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_bytes(base64.b64decode(attrs["profileContent"]))
    print(json.dumps({"bundleId":BUNDLE,"profile":attrs["name"],"uuid":attrs["uuid"],"expires":attrs["expirationDate"]}))

def status():
    apps=call("GET","/v1/apps",{"filter[bundleId]":BUNDLE,"fields[apps]":"name,bundleId","limit":10})["data"]
    if not apps:
        print("No app record. Create ElementalCube (iOS, bundle com.weavatrix.elementalcube) on App Store Connect."); return
    print(json.dumps(apps,indent=2))
    print(json.dumps(call("GET","/v1/builds",{"filter[app]":apps[0]["id"],"sort":"-uploadedDate","limit":5,
        "include":"buildBetaDetail","fields[builds]":"version,processingState,uploadedDate,expired,buildBetaDetail"}),indent=2))

if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command",choices=["prepare-signing","status","request"])
    parser.add_argument("arguments",nargs="*")
    args=parser.parse_args()
    if args.command == "prepare-signing": prepare_signing()
    elif args.command == "status": status()
    else:
        if len(args.arguments) not in (2,3): parser.error("request METHOD /v1/path [JSON_BODY_FILE]")
        method,path=args.arguments[:2]
        body=json.loads(Path(args.arguments[2]).read_text()) if len(args.arguments)==3 else None
        print(json.dumps(call(method.upper(),path,body=body),indent=2))
