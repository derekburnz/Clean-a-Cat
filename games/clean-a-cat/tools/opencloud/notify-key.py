#!/usr/bin/env python3
"""Sets up the build finished notification's key without anyone pasting it (Derek, 2026-11-26, q2-notifykey).

Reads the keys already saved as GitHub secrets (OWNER_KEY, ROBLOX_GROUP_KEY), asks Roblox what each may do (API key
introspection), and with ACTION=install saves the first key that can send user notifications as the experience
secret CleanACat_NotifyKey (Open Cloud secrets store: a LibSodium sealed box with the experience's public key).
NotifyService reads that secret with HttpService:GetSecret. No key is ever printed: only each key's name, whether it
is enabled, and its scope names and operations.

  KEY_OWNER, KEY_GROUP   the keys (either may be empty)
  UNIVERSE_ID            the experience id (not secret)
  ACTION                 check (default), install, or string: find or make the notification string STRING_NAME
                         (the open cloud notification-string API, experimental) and print its id, which is public
                         and goes in NotifyRules.MESSAGE_IDS
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

SECRET_ID = "CleanACat_NotifyKey"
# The only host NotifyService calls: a script that tries to send the secret anywhere else is refused (Review-QA on #769).
SECRET_DOMAIN = "apis.roblox.com"
STRING_NAME = "build_done"
# NotifyService fills {buildName}; 99 characters at most, no false urgency (Roblox's notification guidelines).
STRING_CONTENT = "Your {buildName} is ready! Come back and show it off."
MAX_PAGES = 10  # the list is only a handful of strings; a cap keeps a bad cursor from looping
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


def status_fields(info):
    # Every other field introspection returns, for a moderation check (coordinator, 2026-11-26, after a 403 "User is
    # moderated"): yes or no values and status like words in full, anything else (ids, names, times) only as "set",
    # since run summaries on a public repo are public.
    out = []
    for name in sorted(info):
        if name in ("scopes", "name"):
            continue
        value = info[name]
        word = name.lower()
        if isinstance(value, bool) or value is None:
            out.append(f"{name} {value}")
        elif isinstance(value, str) and any(w in word for w in ("status", "moderat", "state", "reason")):
            out.append(f"{name} {value[:80]}")
        else:
            out.append(f"{name} (set)")
    return ", ".join(out) or "(none)"


def can(scopes, word, op_words=("write", "create", "post")):
    # `word` must name the scope itself: "user.user-notification" (sending), "universe.secret", "notification-string"
    for name, ops in scopes:
        if word in name.lower():
            if not ops or any(any(w in op.lower() for w in op_words) for op in ops):
                return True
    return False


def main():
    universe = os.environ.get("UNIVERSE_ID", "").strip()
    action = os.environ.get("ACTION", "check").strip()
    # the group's key first: it is the one saved in the game, so the owner's own key stays out of it when it can
    keys = [("ROBLOX_GROUP_KEY", os.environ.get("KEY_GROUP", "")), ("OWNER_KEY", os.environ.get("KEY_OWNER", ""))]
    summary = []
    notify_key = None
    secret_key = None
    string_key = None
    for label, key in keys:
        if not key:
            summary.append(f"- {label}: not set")
            continue
        status, info = call("POST", f"{API}/api-keys/v1/introspect", body={"apiKey": key})
        if status != 200:
            summary.append(
                f"- {label}: introspection failed (HTTP {status}: {str(info.get('message', ''))[:200]}; "
                f"fields: {status_fields(info)})"
            )
            continue
        scopes = scopes_of(info)
        usable = info.get("enabled", True) and not info.get("expired", False)
        notify = usable and can(scopes, "user.user-notification")
        secrets = usable and can(scopes, "universe.secret")
        strings = usable and can(scopes, "notification-string")
        summary.append(
            f"- {label} ({info.get('name', '?')}): enabled {info.get('enabled')}, expired {info.get('expired')}, "
            f"notifications {'yes' if notify else 'no'}, secrets store {'yes' if secrets else 'no'}, "
            f"notification strings {'yes' if strings else 'no'}"
        )
        for name, ops in scopes:
            summary.append(f"  - {name}: {', '.join(ops) if ops else '(all)'}")
        summary.append(f"  - other fields: {status_fields(info)}")
        if notify and notify_key is None:
            notify_key = (label, key)
        if secrets and secret_key is None:
            secret_key = (label, key)
        if strings and string_key is None:
            string_key = (label, key)

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
                body = {"id": SECRET_ID, "secret": sealed, "key_id": pk.get("key_id"), "domain": SECRET_DOMAIN}
                status, answer = call("POST", f"{API}/cloud/v2/universes/{universe}/secrets", key=secret_key[1], body=body)
                if status == 409 or (status >= 400 and "exist" in json.dumps(answer).lower()):
                    status, answer = call(
                        "PATCH",
                        f"{API}/cloud/v2/universes/{universe}/secrets/{SECRET_ID}",
                        key=secret_key[1],
                        body={"secret": sealed, "key_id": pk.get("key_id"), "domain": SECRET_DOMAIN},
                    )
                if 200 <= status < 300:
                    summary.append(
                        f"Saved {notify_key[0]} as the experience secret {SECRET_ID} of {universe} (with {secret_key[0]}), "
                        f"usable only for {SECRET_DOMAIN}."
                    )
                elif status == 400 and "domain" in json.dumps(answer).lower():
                    # Never saved without its domain: a secret without one could be sent to any host.
                    summary.append(
                        f"Roblox refused the domain field (HTTP 400: {answer.get('message', '')}). Nothing was saved. "
                        f"Create the secret {SECRET_ID} by hand with domain {SECRET_DOMAIN} instead."
                    )
                    result = 1
                else:
                    summary.append(f"Saving the secret failed (HTTP {status}: {answer.get('message', '')}).")
                    result = 1

    if action == "string":
        if string_key is None:
            summary.append("No key can write notification strings: add universe.notification-string to one of them.")
            result = 1
        else:
            base = f"{API}/notifications/v1/developer-configuration"
            # Look through every page of the list first. Make the string only when the list answered fully and had
            # no build_done: a failed or cut short list must never make a duplicate on each run.
            found = None
            listed_ok = True
            cursor = ""
            seen = set()
            for _ in range(MAX_PAGES):
                query = f"UniverseId={universe}&Count=50" + (f"&Cursor={urllib.parse.quote(cursor)}" if cursor else "")
                status, listed = call("GET", f"{base}/experience-notifications-list?{query}", key=string_key[1])
                if status != 200:
                    summary.append(
                        f"Could not list the notification strings (HTTP {status}: {listed.get('message', '')}),"
                        " so nothing was made."
                    )
                    listed_ok = False
                    break
                for item in listed.get("notificationStringConfigs") or []:
                    if item.get("name") == STRING_NAME:
                        found = item
                cursor = listed.get("nextPageToken") or listed.get("nextPageCursor") or ""
                if found is not None or not cursor:
                    break
                if cursor in seen:
                    summary.append("The notification string list repeated a page, so nothing was made.")
                    listed_ok = False
                    break
                seen.add(cursor)
            else:
                summary.append(f"The notification string list ran past {MAX_PAGES} pages, so nothing was made.")
                listed_ok = False
            if not listed_ok:
                result = 1
            if found is None and listed_ok:
                status, made = call(
                    "POST",
                    f"{base}/create-notification",
                    key=string_key[1],
                    body={"name": STRING_NAME, "content": STRING_CONTENT, "universeId": int(universe)},
                )
                if status == 200 and made.get("id"):
                    found = {"id": made["id"], "name": STRING_NAME, "content": STRING_CONTENT}
                    summary.append(f"Made the notification string {STRING_NAME} (with {string_key[0]}).")
                else:
                    summary.append(f"Making the notification string failed (HTTP {status}: {made.get('message', '')}).")
                    result = 1
            elif found is not None:
                summary.append(f"The notification string {STRING_NAME} already exists.")
            if found is not None:
                summary.append(f"Message id for NotifyRules.MESSAGE_IDS[{universe}]: {found['id']}")
                summary.append(f"Text: {found.get('content', '')}")

    text = "\n".join(summary)
    print(text)
    step = os.environ.get("GITHUB_STEP_SUMMARY")
    if step:
        with open(step, "a") as out:
            out.write(f"## Notification key ({action}, experience {universe})\n\n{text}\n")
    return result


if __name__ == "__main__":
    sys.exit(main())
