local AssetService = game:GetService("AssetService")
local rig = game.ServerStorage:WaitForChild("AnimSaves")

-- Configuration
local USER_ID = 10275863082
local CREATOR_TYPE = Enum.AssetCreatorType.User -- Use .Group if uploading to a group

local function uploadAnimations()
	-- Collect all KeyframeSequences under the rig
	local children = rig:GetChildren()

	for _, obj in ipairs(children) do
		if obj:IsA("KeyframeSequence") then
			local requestParameters = {
				CreatorId = USER_ID,
				CreatorType = CREATOR_TYPE,
				Name = obj.Name,
				Description = "PS: " .. rig.Name,
			}

			-- Use pcall to handle potential upload errors (e.g., rate limits)
			local ok, result, idOrUploadErr = pcall(function()
				return AssetService:CreateAssetAsync(obj, Enum.AssetType.Animation, requestParameters)
			end)

			if not ok then
				warn(`Failed to call CreateAssetAsync for {obj.Name}: {result}`)
			elseif result == Enum.CreateAssetResult.Success then
				print(` {obj.Name}. Asset ID: rbxassetid://{idOrUploadErr}`)
			else
				warn(`Upload error for {obj.Name}: {result}, {idOrUploadErr}`)
			end

			-- Optional: Small wait to avoid hitting rate limits (currently ~30 requests/min)
			task.wait(2)
		end
	end
end

uploadAnimations()