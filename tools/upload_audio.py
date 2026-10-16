#!/usr/bin/env python3
"""Заливает audio/*.ogg в Roblox через Open Cloud Assets API и пишет src/shared/AudioIds.luau.
Запускается в GitHub Actions (секрет ROBLOX_API_KEY). Уже залитые файлы (тот же sha) пропускаются."""
import hashlib, json, os, sys, time, urllib.request, urllib.error, uuid

ROOT = os.path.join(os.path.dirname(__file__), "..")
AUDIO = os.path.join(ROOT, "audio")
IDS = os.path.join(AUDIO, "ids.json")
LUAU = os.path.join(ROOT, "src", "shared", "AudioIds.luau")
KEY = os.environ["API_KEY"]
UNIVERSE = os.environ["UNIVERSE_ID"]


def req(method, url, data=None, headers=None):
    h = {"x-api-key": KEY}
    h.update(headers or {})
    r = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        return e.code, {"error": body}


def creator():
    with urllib.request.urlopen(f"https://games.roblox.com/v1/games?universeIds={UNIVERSE}", timeout=30) as r:
        c = json.loads(r.read())["data"][0]["creator"]
    return {"groupId": str(c["id"])} if c["type"] == "Group" else {"userId": str(c["id"])}


def upload(name, path, who):
    boundary = uuid.uuid4().hex
    meta = {"assetType": "Audio", "displayName": f"SlimeSFX {name}", "description": "Steal a Slime sound effect", "creationContext": {"creator": who}}
    with open(path, "rb") as f:
        blob = f.read()
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n{json.dumps(meta)}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.ogg\"\r\nContent-Type: audio/ogg\r\n\r\n"
    ).encode() + blob + f"\r\n--{boundary}--\r\n".encode()
    code, res = req("POST", "https://apis.roblox.com/assets/v1/assets", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    if code in (401, 403):
        print("::error::API key has no permission to upload assets. In Creator Hub → API Keys → edit the key → add 'Assets' API with Read + Write. Response:", res)
        sys.exit(1)
    if code != 200:
        print(f"::warning::{name}: upload failed {code} {res}")
        return None
    op = res.get("path") or res.get("operationId")
    op_id = op.split("/")[-1]
    for _ in range(90):
        time.sleep(4)
        code, st = req("GET", f"https://apis.roblox.com/assets/v1/operations/{op_id}")
        if st.get("done"):
            aid = (st.get("response") or {}).get("assetId")
            print(f"✓ {name} → {aid}")
            return aid
    print(f"::warning::{name}: still processing, will retry next run")
    return None


def main():
    ids = json.load(open(IDS)) if os.path.exists(IDS) else {}
    who = creator()
    print("creator:", who)
    changed = False
    for fn in sorted(os.listdir(AUDIO)):
        if not fn.endswith(".ogg"):
            continue
        name = fn[:-4]
        path = os.path.join(AUDIO, fn)
        sha = hashlib.sha1(open(path, "rb").read()).hexdigest()
        if ids.get(name, {}).get("sha") == sha and ids[name].get("id"):
            continue
        aid = upload(name, path, who)
        if aid:
            ids[name] = {"id": str(aid), "sha": sha}
            changed = True
    json.dump(ids, open(IDS, "w"), indent=2, sort_keys=True)
    lines = ["--!strict", "-- Сгенерировано tools/upload_audio.py (GitHub Actions). Не редактировать руками.", "return {"]
    for name in sorted(ids):
        lines.append(f'\t{name} = "rbxassetid://{ids[name]["id"]}",')
    lines.append("}")
    open(LUAU, "w").write("\n".join(lines) + "\n")
    print("changed:", changed)


main()
