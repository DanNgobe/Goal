local AssetService = game:GetService("AssetService")
local rootFolder = game.ServerStorage:WaitForChild("RBX_ANIMSAVES")
local rig = rootFolder:WaitForChild("Anim Rig")

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

-- Spin -  rbxassetid://105038181187521  
-- Chest Receive Reaction -  rbxassetid://80989207591118 
-- Strike Right Kick -  rbxassetid://98915153075277 
-- Defeat Reaction -  rbxassetid://128098902820066
-- Goalkeeper Jump Catch -  rbxassetid://114712505227753
-- Goalkeeper Left Diving Save -  rbxassetid://108697504709184 
-- Goalkeeper Place And Kick -  rbxassetid://122860766304040
-- Goalkeeper Right Diving Save -  rbxassetid://90242818409684 
-- Goalkeeper Scoop -  rbxassetid://75857256400779
-- Goalkeeper Standing Catch -  rbxassetid://105132318189724
-- Jump -  rbxassetid://132513360731454
-- Offensive Idle -  rbxassetid://83582883729420 
-- Scissor Kick -  rbxassetid://78083482432819
-- Soccer Header -  rbxassetid://129437047136268
-- Pass Left Kick -  rbxassetid://77626978581980
-- Pass Right Kick -  rbxassetid://77174336937563
-- Penalty Left Kick -  rbxassetid://126405452167582
-- Penalty Right Kick -  rbxassetid://79228843218620
-- Tackle -  rbxassetid://99052712078405
-- Strike Left Kick -  rbxassetid://115005726141789
-- Soccer Tackle Reaction -  rbxassetid://76242028945890 
-- Goalkeeper Trow -  rbxassetid://80160321838497