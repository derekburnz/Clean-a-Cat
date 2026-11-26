#!/usr/bin/env python3
"""Sets up the build finished notification's key without anyone pasting it (Derek, 2026-11-26, q2-notifykey).

Reads the keys already saved as GitHub secrets (OWNER_KEY, ROBLOX_GROUP_KEY), asks Roblox what each may do (API key
introspection), and with ACTION=install saves the first key that can send user notifications as the experience
secret CleanACat_NotifyKey (Open Cloud secrets store: a LibSodium sealed box with the experience's public key).
NotifyService reads that secret with HttpService:GetSecret. No key is ever printed: only each key's name, whether it
is enabled, and its scope names and operations.

  KEY_OWNER, KEY_GROUP   the keys (either may be empty)
  UNIVERSE_ID            the experience id (not secret)
  ACTION                 check (default) or install
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

SECRET_ID = "CleanACat_NotifyKey"
API = "https://apis.roblox.com"


def call(method, url, key=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if key:
        headers["x-api-key"] = key
    for wait in (5, 10, 20, 0):
        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as res:
                text = res.read().decode() or "{}"
                return res.status, json.loads(text)
        except urllib.error.HTTPError as err:
            text = err.read().decode()
            if err.code in (429, 500, 502, 503, 504) and wait:
                time.sleep(wait)
                continue
            try:
                return err.code, json.loads(text or "{}")
            except ValueError:
                return err.code, {"message": text[:300]}
        except urllib.error.URLError as err:
            if wait:
                time.sleep(wait)
                continue
            return 0, {"message": str(err.reason)}
    return 0, {}


def scopes_of(info):
    found = []
    for scope in info.get("scopes") or []:
        name = str(scope.get("name") or scope.get("scopeType") or "?")
        ops = scope.get("operations") or []
        found.append((name, [str(op) for op in ops]))
    return found


def can(scopes, word, op_words=("write", "create", "post")):
    for name, ops in scopes:
        if word in name.lower():
            if not ops or any(any(w in op.lower() for w in op_words) for op in ops):
                return True
    return False


def main():
    universe = os.environ.get("UNIVERSE_ID", "").strip()
    action = os.environ.get("ACTION", "check").strip()
    keys = [("OWNER_KEY", os.environ.get("KEY_OWNER", "")), ("ROBLOX_GROUP_KEY", os.environ.get("KEY_GROUP", ""))]
    summary = []
    notify_key = None
    secret_key = None
    for label, key in keys:
        if not key:
            summary.append(f"- {label}: not set")
            continue
        status, info = call("POST", f"{API}/api-keys/v1/introspect", body={"apiKey": key})
        if status != 200:
            summary.append(f"- {label}: introspection failed (HTTP {status}: {info.get('message', '')})")
            continue
        scopes = scopes_of(info)
        usable = info.get("enabled", True) and not info.get("expired", False)
        notify = usable and can(scopes, "notification")
        secrets = usable and can(scopes, "secret")
        summary.append(
            f"- {label} ({info.get('name', '?')}): enabled {info.get('enabled')}, expired {info.get('expired')}, "
            f"notifications {'yes' if notify else 'no'}, secrets store {'yes' if secrets else 'no'}"
        )
        for name, ops in scopes:
            summary.append(f"  - {name}: {', '.join(ops) if ops else '(all)'}")
        if notify and notify_key is None:
            notify_key = (label, key)
        if secrets and secret_key is None:
            secret_key = (label, key)

    result = 0
    if notify_key is None:
        summary.append("No key can send user notifications: add the User Notification API with write to one of them.")
        result = 1
    else:
        summary.append(f"Notifications would use {notify_key[0]}.")
    if action == "install" and notify_key is not None:
        if secret_key is None:
            summary.append("No key can write the secrets store: add the Secrets Store API with write to one of them.")
            result = 1
        else:
            try:
                from nacl import public  # PyNaCl, installed by the workflow
            except ImportError:
                print("::error::PyNaCl is missing")
                return 1
            status, pk = call("GET", f"{API}/cloud/v2/universes/{universe}/secrets/public-key", key=secret_key[1])
            if status != 200 or "secret" not in pk:
                summary.append(f"Could not read the experience's public key (HTTP {status}: {pk.get('message', '')}).")
                result = 1
            else:
                box = public.SealedBox(public.PublicKey(base64.b64decode(pk["secret"])))
                sealed = base64.b64encode(box.encrypt(notify_key[1].encode())).decode()
                body = {"id": SECRET_ID, "secret": sealed, "key_id": pk.get("key_id")}
                status, answer = call("POST", f"{API}/cloud/v2/universes/{universe}/secrets", key=secret_key[1], body=body)
                if status == 409 or (status >= 400 and "exist" in json.dumps(answer).lower()):
                    status, answer = call(
                        "PATCH",
                        f"{API}/cloud/v2/universes/{universe}/secrets/{SECRET_ID}",
                        key=secret_key[1],
                        body={"secret": sealed, "key_id": pk.get("key_id")},
                    )
                if 200 <= status < 300:
                    summary.append(
                        f"Saved {notify_key[0]} as the experience secret {SECRET_ID} of {universe} (with {secret_key[0]})."
                    )
                else:
                    summary.append(f"Saving the secret failed (HTTP {status}: {answer.get('message', '')}).")
                    result = 1

    text = "\n".join(summary)
    print(text)
    step = os.environ.get("GITHUB_STEP_SUMMARY")
    if step:
        with open(step, "a") as out:
            out.write(f"## Notification key ({action}, experience {universe})\n\n{text}\n")
    return result


if __name__ == "__main__":
    sys.exit(main())
