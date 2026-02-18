--[[
	DonationHandler.lua
	Server-side donation processing and tracking
]]

local DonationHandler = {}

-- Services
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- DataStore
local AmountODS = DataStoreService:GetOrderedDataStore("Donations")

-- Product ID to price mapping
local PRODUCT_PRICES = {
	[3537974762] = 10,
	[3537976383] = 100,
	[3537976964] = 1000
}

-- Process receipt callback
local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local productId = receiptInfo.ProductId
	local price = PRODUCT_PRICES[productId]
	
	if not price then
		warn("Unknown product ID:", productId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	-- Increment donation amount in DataStore
	local success, errorMessage = pcall(function()
		AmountODS:IncrementAsync(receiptInfo.PlayerId, price)
	end)
	
	if success then
		print(string.format("Donation received: R$%d from Player %s (UserId: %d)", 
			price, player and player.Name or "Unknown", receiptInfo.PlayerId))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("Failed to save donation:", errorMessage)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function DonationHandler.Initialize()
	-- Set the process receipt callback
	MarketplaceService.ProcessReceipt = processReceipt
	print("DonationHandler initialized")
end

-- Optional: Get total donations for a player
function DonationHandler.GetPlayerDonations(userId)
	local success, result = pcall(function()
		return AmountODS:GetAsync(userId)
	end)
	
	if success then
		return result or 0
	else
		warn("Failed to get donations for user:", userId)
		return 0
	end
end

-- Optional: Get top donors
function DonationHandler.GetTopDonors(count)
	count = count or 10
	local success, pages = pcall(function()
		return AmountODS:GetSortedAsync(false, count)
	end)
	
	if success then
		local topDonors = {}
		local currentPage = pages:GetCurrentPage()
		
		for _, entry in ipairs(currentPage) do
			table.insert(topDonors, {
				userId = entry.key,
				amount = entry.value
			})
		end
		
		return topDonors
	else
		warn("Failed to get top donors")
		return {}
	end
end

return DonationHandler
