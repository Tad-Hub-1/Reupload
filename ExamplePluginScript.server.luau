-- ExamplePluginScript.server.luau
-- นี่คือสคริปต์หลักของ Plugin ของคุณ

-- 1. ตรวจสอบว่า HttpService ใช้งานได้ (จำเป็นสำหรับ JSONDecode)
local HttpService
try
    HttpService = game:GetService("HttpService")
catch e
    warn("HttpService is not enabled. Cannot decode JSON. Please enable HttpService in Game Settings.")
    return
end

-- 2. โหลด "สมอง" ของคุณ (โมดูล AssetIdFilter ที่คุณสร้างไว้)
local AssetIdFilter = require(script.Parent.AssetIdFilter) -- <--- แก้ไข path ให้ถูกต้อง

-- 3. สร้างปุ่มบน Toolbar
local toolbar = plugin:CreateToolbar("Asset Reuploader")
local replaceButton = toolbar:CreateButton(
    "Load ID Map & Replace",
    "Loads reupload_map.json and replaces all IDs in the game",
    "rbxassetid://4442250482" -- ไอคอนตัวอย่าง
)

-- 4. เมื่อปุ่มถูกคลิก
replaceButton.Click:Connect(function()
    print("[Reuploader Plugin] Waiting for user to select 'reupload_map.json'...")
    
    local file
    try
        -- เปิดหน้าต่างให้ผู้ใช้เลือกไฟล์ .json
        file = plugin:ImportFile("*.json", "Select reupload_map.json")
    catch e
        warn("File import failed or was cancelled:", e)
        return
    end

    if not file then
        print("[Reuploader Plugin] File selection cancelled.")
        return
    end

    print("[Reuploader Plugin] File selected:", file.Name)
    
    -- 5. อ่านและถอดรหัสไฟล์ JSON
    local content = file:Read()
    local idsToChange -- นี่คือ list ของ IdPair {oldId, newId}
    
    local success, result = pcall(function()
        idsToChange = HttpService:JSONDecode(content)
    end)
    
    if not success then
        warn("[Reuploader Plugin] ERROR: Failed to decode JSON from file.", result)
        return
    end
    
    if not idsToChange or typeof(idsToChange) ~= "table" then
        warn("[Reuploader Plugin] ERROR: JSON content is not a valid ID map list.")
        return
    end

    print(string.format("[Reuploader Plugin] Loaded %d ID pairs from map.", #idsToChange))

    -- 6. กำหนดค่าการค้นหา (คุณสามารถปรับแต่งส่วนนี้ได้)
    local filterOptions: AssetIdFilter.FilterOptions = {
        -- ค้นหาใน Instance ทั้งหมดในเกม
        Instances = {game}, 
        
        -- ค้นหา Asset ประเภทใดบ้าง (ตามที่โมดูลของคุณรองรับ)
        WhitelistedInstances = {
            "Animation",
            "Sound",
            "NumberValue",
            "IntValue",
            "StringValue",
            "CharacterMesh",
            "MeshPart",
            "SpecialMesh",
            "LuaSourceContainer" -- (สำหรับ Script, LocalScript, ModuleScript)
        }
    }

    print("[Reuploader Plugin] Finding all instances with old IDs...")
    
    -- 7. ค้นหา ID เก่าทั้งหมด (เรียกใช้ GetAssetIds.luau)
    local filteredIds = AssetIdFilter.filterInstances(filterOptions)
    
    print("[Reuploader Plugin] Found instances. Starting replacement process...")

    -- 8. สั่งเปลี่ยน ID (เรียกใช้ ChangeIds.luau)
    AssetIdFilter.replaceIds(filteredIds, idsToChange)
    
    print("[Reuploader Plugin] COMPLETE: All IDs have been replaced!")
end)

print("[Reuploader Plugin] Ready. Click the 'Load ID Map' button.")
