-- Bulk Animation Uploader
-- Run via: Plugins tab -> Script -> Run, or paste into the Command Bar (Studio)
-- Uploads all KeyframeSequences under ServerStorage -> RBX_ANIMSAVES -> Robuta

local AssetService = game:GetService("AssetService")

-- Configuration
local USER_ID     = 10275863082
local CREATOR_TYPE = Enum.AssetCreatorType.User  -- swap to .Group if uploading to a group

-- Resolve the rig folder safely
local animSaves = game:GetService("ServerStorage"):FindFirstChild("RBX_ANIMSAVES")
local rig       = animSaves and animSaves:FindFirstChild("Rig")

if not rig then
	error("Could not find ServerStorage -> RBX_ANIMSAVES -> Rig. Aborting.")
end

local function uploadAnimations()
	local uploaded = 0
	local failed   = 0

	for _, obj in ipairs(rig:GetChildren()) do
		if not obj:IsA("KeyframeSequence") then continue end

		local requestParameters = {
			CreatorId   = USER_ID,
			CreatorType = CREATOR_TYPE,
			Name        = obj.Name,
			Description = rig.Name,
		}

		local ok, result, idOrErr = pcall(function()
			return AssetService:CreateAssetAsync(
				obj,
				Enum.AssetType.Animation,
				requestParameters
			)
		end)

		if not ok then
			warn(string.format("[UPLOAD] pcall error for '%s': %s", obj.Name, tostring(result)))
			failed += 1
		elseif result == Enum.CreateAssetResult.Success then
			print(string.format("[UPLOAD] OK  '%s'  ->  rbxassetid://%s", obj.Name, tostring(idOrErr)))
			uploaded += 1
		else
			warn(string.format("[UPLOAD] FAIL '%s'  result=%s  detail=%s", obj.Name, tostring(result), tostring(idOrErr)))
			failed += 1
		end

		-- ~30 req/min limit -> 2s gap keeps us safely under
		task.wait(2)
	end

	print(string.format("\n[UPLOAD] Done. Uploaded: %d  |  Failed: %d", uploaded, failed))
end

uploadAnimations()
