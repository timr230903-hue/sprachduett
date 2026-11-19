#!/usr/bin/env python3
"""Vorabprüfung gegen die App Store Connect API (nur lesend).

Prüft den App-Eintrag und die nächste freie Build-Nummer.
Umgebung: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID, BUNDLE_ID,
          BUILD_NUMBER, optional EXPECTED_APP_ID, optional GITHUB_ENV.
"""
import base64, json, os, sys, time, urllib.error, urllib.parse, urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

API = "https://api.appstoreconnect.apple.com"


def b64url(data: bytes) -> bytes:
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def make_token(key_path: str, key_id: str, issuer: str) -> str:
    with open(key_path, "rb") as f:
        key = serialization.load_pem_private_key(f.read(), password=None)
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = b64url(json.dumps({
        "iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"
    }).encode())
    signed = key.sign(header + b"." + payload, ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(signed)
    sig = b64url(r.to_bytes(32, "big") + s.to_bytes(32, "big"))
    return (header + b"." + payload + b"." + sig).decode()


def get(token: str, path: str, params: dict) -> tuple[int, dict]:
    url = API + path + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"{}")


def main() -> int:
    env = os.environ
    token = make_token(env["ASC_KEY_PATH"], env["ASC_KEY_ID"], env["ASC_ISSUER_ID"])
    bundle_id = env["BUNDLE_ID"]
    wanted = int(env.get("BUILD_NUMBER") or "1")
    expected = env.get("EXPECTED_APP_ID", "")

    status, data = get(token, "/v1/apps", {
        "filter[bundleId]": bundle_id,
        "fields[apps]": "name,bundleId,sku",
    })
    if status == 401:
        print("::error::App Store Connect lehnt den API-Schlüssel ab (401).")
        return 1
    if status != 200:
        print(f"::error::App Store Connect API antwortet mit {status}: {json.dumps(data)[:500]}")
        return 1
    apps = [item for item in data.get("data", []) if item["attributes"].get("bundleId") == bundle_id]
    if not apps:
        print(f"::error::Kein App-Eintrag für {bundle_id}.")
        return 1
    app = apps[0]
    if expected and app["id"] != expected:
        print(f"::error::App-ID {app['id']} ist nicht die erwartete {expected}.")
        return 1
    print(f"App-Eintrag: {app['attributes'].get('name')} (id {app['id']})")

    highest = 0
    status, data = get(token, "/v1/builds", {
        "filter[app]": app["id"],
        "sort": "-uploadedDate",
        "limit": "50",
        "fields[builds]": "version,uploadedDate,processingState",
    })
    if status == 200:
        for build in data.get("data", []):
            try:
                highest = max(highest, int(build["attributes"].get("version", "0")))
            except ValueError:
                pass
        print(f"Höchste bisherige Build-Nummer: {highest or 'keine'}")
    else:
        print(f"::warning::Builds nicht lesbar ({status}); nehme {wanted}.")

    build = wanted if highest < wanted else highest + 1
    if build != wanted:
        print(f"::warning::Build {wanted} ist vergeben, nehme {build}.")
    print(f"CFBundleVersion: {build}")
    if env.get("GITHUB_ENV"):
        with open(env["GITHUB_ENV"], "a", encoding="utf-8") as handle:
            handle.write(f"BUILD_NUMBER={build}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
