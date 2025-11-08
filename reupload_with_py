#!/usr/bin/env python3
"""
reupload_with_map.py
Fetches and reuploads assets, then generates a JSON map (reupload_map.json)
of {oldId, newId} pairs for a Roblox plugin to consume.

YOU MUST PROVIDE CREDENTIALS YOURSELF (either X_API_KEY or ROBLOSECURITY_COOKIE).
"""

import os
import sys
import json
import time
import mimetypes
from pathlib import Path
import xml.etree.ElementTree as ET

try:
    import requests
except Exception:
    print("Please install requests: pip install requests")
    sys.exit(1)

# ----------------- Config loading -----------------
BASE_DIR = Path(__file__).parent
CFG_PATH = BASE_DIR / "config.json"

DEFAULT_CFG = {
    "x_api_key": None,
    "roblosecurity": None,
    "download_endpoint": "https://apis.roblox.com/asset-delivery-api/v1/assetId/{assetId}",
    "upload_endpoint": "https://apis.roblox.com/assets/v1/assets"
}

# (ส่วน Config loading เหมือนเดิม)
if CFG_PATH.exists():
    cfg = json.loads(CFG_PATH.read_text(encoding="utf-8"))
else:
    cfg = DEFAULT_CFG.copy()
    if not CFG_PATH.exists():
        CFG_PATH.write_text(json.dumps(DEFAULT_CFG, indent=2), encoding="utf-8")
        print(f"[INFO] Created example config.json at {CFG_PATH}. Edit it to add your x_api_key or roblosecurity.")
        print("Edit config.json and add your credentials, then re-run this script.")
cfg = {**DEFAULT_CFG, **(cfg or {})}

# ----------------- Helpers (เหมือนเดิม) -----------------
def build_headers():
    headers = { "User-Agent": "AssetReuploaderTemplate/1.2" }
    if cfg.get("x_api_key"):
        headers["x-api-key"] = cfg["x_api_key"]
    if cfg.get("roblosecurity"):
        headers["Cookie"] = f".ROBLOSECURITY={cfg['roblosecurity']}"
    return headers

def guess_mime_from_name(name: str):
    t, _ = mimetypes.guess_type(name)
    return t or "application/octet-stream"

# ----------------- File Extractor (เหมือนเดิม) -----------------
def extract_animation_ids(rbxl_path):
    try:
        tree = ET.parse(rbxl_path)
        root = tree.getroot()
    except Exception as e:
        print(f"[ERROR] ไม่สามารถเปิดไฟล์ {rbxl_path}: {e}")
        return set()
    animation_ids = set()
    print(f"[INFO] กำลังค้นหาไฟล์ {rbxl_path}...")
    for item in root.findall(".//Item"):
        properties = item.find("Properties")
        if properties is None: continue
        for prop in properties:
            if "AnimationId" in prop.tag or "AnimationId" in (prop.attrib.get("name") or ""):
                value = prop.text
                if value:
                    if "rbxassetid://" in value:
                        value = value.replace("rbxassetid://", "")
                    if value.isdigit():
                        animation_ids.add(value)
    return animation_ids

# ----------------- Download/Upload (เหมือนเดิม) -----------------
def download_asset(asset_id):
    url = cfg["download_endpoint"].format(assetId=asset_id)
    headers = build_headers()
    try:
        r = requests.get(url, headers=headers, timeout=15, allow_redirects=True, stream=True)
    except Exception as e:
        return False, f"Request error: {e}"
    if r.status_code >= 400:
        return False, f"Download failed {r.status_code}: {r.text[:400]}"
    
    filename = None
    cd = r.headers.get("Content-Disposition")
    if cd and "filename=" in cd:
        filename = cd.split("filename=")[-1].strip(' "')
    if not filename:
        ct = r.headers.get("Content-Type", "")
        ext = ".bin"
        if "xml" in ct: ext = ".rbxm"
        elif "text/xml" in ct or "application/xml" in ct: ext = ".rbxm"
        filename = f"asset_{asset_id}{ext}"
    try:
        content = r.content
    except Exception as e:
        return False, f"Failed read content: {e}"
    return True, {"bytes": content, "filename": filename}

def upload_asset(file_bytes, filename, display_name, description, asset_type):
    url = cfg["upload_endpoint"]
    headers = build_headers()
    request_payload = {
        "assetType": asset_type or "Model",
        "displayName": display_name,
        "description": description,
        "creationContext": {}
    }
    files = {
        "request": (None, json.dumps(request_payload), "application/json"),
        "fileContent": (filename, file_bytes, guess_mime_from_name(filename))
    }
    try:
        r = requests.post(url, headers=headers, files=files, timeout=30)
    except Exception as e:
        return False, f"Upload request failed: {e}"
    if r.status_code >= 400:
        return False, f"Upload failed {r.status_code}: {r.text[:1000]}"
    try:
        return True, r.json()
    except Exception:
        return False, f"Upload returned non-json: {r.text[:1000]}"

# ----------------- Reupload Logic (อัปเกรด) -----------------
def process_reupload(asset_id, dname, ddesc, atype):
    """
    ประมวลผล 1 Asset ID
    คืนค่า (True, new_id) ถ้าสำเร็จ หรือ (False, None) ถ้าล้มเหลว
    """
    try:
        asset_id_int = int(asset_id)
    except ValueError:
        print(f"[ERROR] Invalid AssetId: {asset_id}. Must be a number. Skipping.")
        return False, None

    print(f"\n--- Processing AssetId: {asset_id_int} ---")
    print(f"[STEP] Downloading asset {asset_id_int} ...")
    ok, data = download_asset(asset_id_int)
    if not ok:
        print(f"[ERROR] Download failed for {asset_id_int}: {data}")
        return False, None

    print(f"[OK] Downloaded {asset_id_int}. filename: {data['filename']}")
    print(f"[STEP] Uploading new asset (Name: {dname})...")
    ok, res = upload_asset(data["bytes"], data["filename"], display_name=dname, description=ddesc, asset_type=atype)
    if not ok:
        print(f"[ERROR] Upload failed for {asset_id_int}: {res}")
        return False, None

    print(f"[SUCCESS] Upload response for original {asset_id_int}:")
    new_id = None
    if isinstance(res, dict):
        new_id = res.get("assetId") or res.get("id") or res.get("data", {}).get("assetId")
    
    if new_id:
        print(f"Original ID: {asset_id_int}  --->  New Asset ID: {new_id}")
        print("-" * 60)
        time.sleep(1) 
        return True, new_id
    else:
        print(f"Could not find new asset id for {asset_id_int} in response:")
        print(json.dumps(res, indent=2))
        print("-" * 60)
        time.sleep(1)
        return False, None

# ----------------- Save Map Function (ใหม่) -----------------
def save_id_map(id_pairs_list):
    """
    รับ list ของ tuples (old_id, new_id) และบันทึกเป็น json
    ที่เข้ากันได้กับ IdPair type ของ Luau
    """
    # แปลงเป็น format ที่ Luau script ของคุณต้องการ: {oldId: number, newId: number}
    map_data = []
    for old, new in id_pairs_list:
        map_data.append({"oldId": int(old), "newId": int(new)})

    map_filename = "reupload_map.json"
    try:
        with open(BASE_DIR / map_filename, "w", encoding="utf-8") as f:
            json.dump(map_data, f, indent=2)
        print(f"\n[COMPLETE] บันทึกแผนที่ ID (ID map) ไว้ที่ {BASE_DIR / map_filename} เรียบร้อยแล้ว")
        print("ใช้ไฟล์นี้ใน Roblox Plugin ของคุณเพื่อทำการแทนที่ ID")
    except Exception as e:
        print(f"\n[ERROR] ไม่สามารถบันทึก ID map file: {e}")

# ----------------- CLI flow (อัปเกรด) -----------------
def main():
    print("Asset Reupload & Map Generator")
    if not cfg.get("x_api_key") and not cfg.get("roblosecurity"):
        print("[WARNING] No auth configured. Edit config.json. Exiting.")
        return

    all_id_pairs = [] # <--- ตัวเก็บ ID ที่อัปโหลดสำเร็จ

    while True:
        print("\nChoose operation mode:")
        print("  1: Batch reupload from .rbxl file (for Animations)")
        print("  2: Manual reupload by AssetId")
        print("  q: Quit")
        mode = input("Enter mode (1, 2, or q): ").strip().lower()

        if mode == 'q':
            print("Exiting.")
            break
        
        all_id_pairs = [] # <--- รีเซ็ตทุกครั้งที่เริ่มโหมดใหม่

        # ----- โหมดที่ 1: Batch จากไฟล์ -----
        if mode == '1':
            fpath = input("Enter path to your .rbxl file: ").strip(' "')
            if not Path(fpath).exists():
                print(f"[ERROR] File not found: {fpath}")
                continue
            
            ids_to_process = extract_animation_ids(fpath)
            if not ids_to_process:
                print("No AnimationIds found in the file.")
                continue

            print(f"[INFO] Found {len(ids_to_process)} unique AnimationId(s).")
            dname_prefix = input("Enter Display Name Prefix (e.g., 'MyGame_'): ").strip()
            ddesc = input("Enter Description (optional, same for all): ").strip()
            atype = input("Asset Type (e.g., Animation, Model) [Animation]: ").strip() or "Animation"

            print(f"\n[BATCH] Starting reupload for {len(ids_to_process)} assets...")
            count = 0
            for asset_id in sorted(ids_to_process):
                count += 1
                dname = f"{dname_prefix}{asset_id}"
                print(f"[BATCH {count}/{len(ids_to_process)}]")
                
                success, new_id = process_reupload(asset_id, dname, ddesc, atype)
                
                if success and new_id:
                    all_id_pairs.append((asset_id, new_id)) # <--- เก็บ ID ที่สำเร็จ
            
            print("[BATCH] Batch processing complete.")
            if all_id_pairs:
                save_id_map(all_id_pairs) # <--- บันทึกไฟล์หลังจบ batch

        # ----- โหมดที่ 2: ป้อน ID เอง -----
        elif mode == '2':
            print("Entering Manual Mode...")
            while True:
                aid = input("Enter AssetId to reupload (or 'b' to go back, 'q' to quit): ").strip()
                if aid.lower() in ("q", "quit", "exit"):
                    print("Exiting.")
                    if all_id_pairs:
                        save_id_map(all_id_pairs) # <--- บันทึกไฟล์ก่อนออก
                    sys.exit()
                if aid.lower() == 'b':
                    print("Returning to main menu...")
                    if all_id_pairs:
                        save_id_map(all_id_pairs) # <--- บันทึกไฟล์ก่อนกลับเมนู
                    break 
                
                if not aid.isdigit():
                    print("AssetId must be a number.")
                    continue
                
                dname = input(f"Enter display name for new asset (empty to use Reupload_{aid}): ").strip() or f"Reupload_{aid}"
                ddesc = input("Enter description (optional): ").strip()
                atype = input("Asset type (Model/Decal/Audio) [Model]: ").strip() or "Model"

                success, new_id = process_reupload(aid, dname, ddesc, atype)
                if success and new_id:
                    all_id_pairs.append((aid, new_id)) # <--- เก็บ ID ที่สำเร็จ

        else:
            print("Invalid mode. Please enter 1, 2, or q.")

if __name__ == "__main__":
    main()
