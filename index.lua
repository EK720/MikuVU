pcall(Network.term)
-- Initialize network
Network.init()

-- Load JSON parser
local json = dofile("app0:/deps/lua/json.lua")
-- Load font and set font size
local fnt0 = Font.load("app0:/deps/font/ShinGo.ttf")
Font.setPixelSizes(fnt0, 25)
-- Define colors
local white, translucentBlack = Color.new(255,255,255), Color.new(0,0,0,160)
-- Init values
local currentId = nil		-- ID of the currently loaded image, used when saving images
local autoNext = 0			-- Auto next variable
local seconds = 5			-- Delay in seconds
local rating = 1			-- max rating allowed (0=general, 1=sensitive, 2=questionable, 3=explicit) 
local ratingURL="-rating:questionable+-rating:explicit" -- URL additive related to the rating var above
local response = nil		-- Response of function ID (used in main loop)
local message = ""			-- Callback Message (used in main loop)
local status = nil			-- Callback Status	(used in main loop)
local fullRes = false		-- Is the loaded image a sample or full-size?
local fullUrl = ""			-- Hold URL of full-size image for downloading
local tmr = Timer.new()		-- Set timer for auto next
Timer.pause(tmr)			-- Pause timer at 0 (would run otherwise)
local tmr2 = Timer.new()	-- Set timer for delays in main loop
Timer.pause(tmr2)			-- Pause timer at 0
local buttonDown = false	-- Ensures no input lag and no unpredicted calls to functions every loop
local menu = false			-- If menu is open
local jsonValid = true		-- Valid JSON Response (Default True)

-- Functions

-- Increases auto next delay
function timerIncrease()
	local id = 1
	if menu then
		if seconds >= 5 and seconds < 60 then
			seconds = seconds + 5
		end
	end
	return id
end
-- Decreases auto next delay
function timerDecrease()
	local id = 2
	if menu then
		if seconds > 5 and seconds <= 60 then
			seconds = seconds - 5
		end
	end
	return id
end
-- Toggles auto next
function toggleAutoNext()
	local id = 3
	if menu then
		if autoNext == 0 then
			if not Timer.isPlaying(tmr) then
				Timer.resume(tmr)
			end
			Timer.setTime(tmr, seconds * 1000)	-- Set time in milliseconds
			autoNext = 1
		else
			if Timer.isPlaying(tmr) then
				Timer.pause(tmr)
			end
			autoNext = 0
		end
	end
	return id
end
-- Saves image with the ID as name
function saveImage()
	local id = 4
	if System.doesFileExist("ux0:/data/MikuVU/SAVED/" .. currentId .. ".jpg") then
		return id, "Image Already Saved", 0
	elseif img ~= nil then
		if fullRes then
			local new = System.openFile("ux0:/data/MikuVU/SAVED/" .. currentId .. ".jpg", FCREATE)
			System.writeFile(new, image, size2)		-- Image data and Size Loaded in getmiku()
			System.closeFile(new)
		else
			local fullExt = string.lower(string.match(fullUrl,"%.[%a%d]+$"))
			Network.downloadFile(fullUrl, "ux0:/data/MikuVU/SAVED/" .. currentId .. fullExt)
		end
		return id, "Saved | " .. currentId .. ".jpg", 1
	else	
		return id, "Error | Failed", 2
	end
end
-- Cycle through filter settings
function changeFilter()
	local id = 5
	rating = (rating+1)%4 
	if rating==0 then
		ratingURL="rating:general"
		return id, "General"
	elseif rating==1 then
		ratingURL="-rating:questionable+-rating:explicit"
		return id, "Sensitive"
	elseif rating==2 then
		ratingURL="-rating:explicit"
		return id, "Questionable"
	else
		ratingURL=""
		return id, "Explicit"
	end
end
-- Gets and loads pictures from decoded JSON
function getmiku()
	::getmiku::
	if Network.isWifiEnabled() then
		Network.downloadFile("https://gelbooru.com/index.php?limit=1&page=dapi&s=post&q=index&json=1&tags=hatsune_miku+-furry+-animal_ears+sort:random+highres+"..ratingURL, "ux0:/data/MikuVU/post.json") 
		local file1 = System.openFile("ux0:/data/MikuVU/post.json", FREAD)
		local size1 = System.sizeFile(file1)
		local jsonEncoded = System.readFile(file1, size1)					-- Encoded JSON file data
		local pcallStat, jsonDecoded = pcall(json.decode, jsonEncoded)		-- Decoded JSON to table
		System.closeFile(file1)
		System.deleteFile("ux0:/data/MikuVU/post.json")
		if not pcallStat then
			jsonValid = pcallStat
			return
		end
		jsonValid = pcallStat
		if img ~= nil then
			Graphics.freeImage(img)
			img = nil
		end
		-- if sample (smaller) image doesn't exist, display full-size image instead
		url = jsonDecoded["post"][1]["sample_url"]
		fullUrl = jsonDecoded["post"][1]["file_url"]
		fullRes = false
		if url == "" then 
			url = fullUrl
			fullRes = true
		end
		
		fileExt = string.lower(string.sub(url, -4, -1)) 
		if fileExt ~= "jpeg" and fileExt ~= ".jpg" then
			goto getmiku
		end
		
		currentId = jsonDecoded["post"][1]["id"] 
		Network.downloadFile(url, "ux0:/data/MikuVU/MikuVU.jpg")
		local file2 = System.openFile("ux0:/data/MikuVU/MikuVU.jpg", FREAD)
		size2 = System.sizeFile(file2)
		if size2 == 0 then
			System.closeFile(file2)
			goto getmiku
		end
		image = System.readFile(file2, size2)
		System.closeFile(file2)
		img = Graphics.loadImage("ux0:/data/MikuVU/MikuVU.jpg")
		System.deleteFile("ux0:/data/MikuVU/MikuVU.jpg")
		width = Graphics.getImageWidth(img)
		height = Graphics.getImageHeight(img)
		drawWidth = 480 - (width * 544 / height / 2)
		drawHeight = 272 - (height * 960 / width / 2)
		if (autoNext == 1) then 
			Timer.setTime(tmr, seconds * 1000) -- Set time in seconds
		end
	else
		img = nil
	end
end

-- Check if ux0:/data/MikuVU exists
if not System.doesDirExist("ux0:/data/MikuVU") then
	System.createDirectory("ux0:/data/MikuVU")
end
-- Check if SAVED folder exists
if not System.doesDirExist("ux0:/data/MikuVU/SAVED") then
	System.createDirectory("ux0:/data/MikuVU/SAVED")
end

getmiku()

-- Main loop
while true do
	-- Local init values
	local time = Timer.getTime(tmr)			            -- Auto next timer value
	local timeSec = math.floor(-time / 1000) + 1		-- Auto next timer value in seconds for user
	local pad = Controls.read()                         -- Reading controls
	local delay = Timer.getTime(tmr2)		            -- Timer used for informational display delays
	local delaySec = 4000					            -- Value used for the delay timer

	-- Controls
	if jsonValid and Network.isWifiEnabled() and img ~= nil then
		if Controls.check(pad, SCE_CTRL_CROSS) or Controls.check(pad, SCE_CTRL_DOWN) or (autoNext == 1 and time > 0) then
			getmiku()
		elseif Controls.check(pad, SCE_CTRL_CIRCLE) or Controls.check(pad, SCE_CTRL_RIGHT) then
			if not buttonDown then
				response = timerIncrease()
			end
			buttonDown = true
		elseif Controls.check(pad, SCE_CTRL_SQUARE) or Controls.check(pad, SCE_CTRL_LEFT) then
			if not buttonDown then
				response = timerDecrease()
			end
			buttonDown = true
		elseif (Controls.check(pad, SCE_CTRL_TRIANGLE) or Controls.check(pad, SCE_CTRL_UP)) then
			if not buttonDown then
				response = toggleAutoNext()
			end
			buttonDown = true
		elseif (Controls.check(pad, SCE_CTRL_LTRIGGER) or Controls.check(pad, SCE_CTRL_RTRIGGER)) then
			if not buttonDown then
				response, message, status = saveImage()
			end
			buttonDown = true
		elseif (Controls.check(pad, SCE_CTRL_SELECT)) then
			if not buttonDown then
				response, message = changeFilter()
			end
			buttonDown = true
		else
			buttonDown = false
		end
	end

	-- "Menu" delay
	if buttonDown then		-- Button was pressed, show information
		if Timer.isPlaying(tmr2) then
			Timer.pause(tmr2)
		end
		Timer.resume(tmr2)
		Timer.setTime(tmr2, delaySec)	-- Set delay in milliseconds
	else					-- Handle the informational display delay timer
		if delay > 0 then
			Timer.pause(tmr2)
		end
	end

	-- Start drawing
	Graphics.initBlend()
	Screen.clear()
	if not Network.isWifiEnabled() then
		Graphics.debugPrint(5, 220, "Error | Check Network Connection", Color.new(255,255,255))
	elseif not jsonValid then 
		Graphics.debugPrint(5, 220, "Error | Check Network Connection", Color.new(255,255,255))
	elseif img == nil then
		Graphics.debugPrint(5, 220, "Error | Check Network Connection", Color.new(255,255,255))
	else
		if height > width then
			Graphics.drawScaleImage(drawWidth, 0, img, 544 / height, 544 / height)
		elseif width > height then
			Graphics.drawScaleImage(0, drawHeight, img, 960 / width, 960 / width)
		end
	end

	-- "Menu"
	if delay < 0 then			-- Informational display delay dimer is set, print info by function ID
		menu = true				-- Set menu visibility to false
		if response == 1 or response == 2 then 													-- timerIncrease()/timerDecrease()
			Graphics.fillRect(15, 250, 30, 80, translucentBlack)
			Font.print(fnt0, 20, 30, string.format("Delay | %02ds", seconds), white)
		elseif response == 3 then																-- toggleAutoNext()
			Graphics.fillRect(15, 250, 30, 80, translucentBlack)								
			if Timer.isPlaying(tmr) then
				Font.print(fnt0, 20, 30, string.format("Timer | %02ds", timeSec), white)
			else
				Font.print(fnt0, 20, 30, "Timer | Off", white)
			end
		elseif response == 4 then
			menu = false
			if status == 0 then
				Graphics.fillRect(15, 325, 30, 80, translucentBlack)
			elseif status == 1 then
				Graphics.fillRect(15, 325, 30, 80, translucentBlack)
			else
				Graphics.fillRect(15, 325, 30, 80, translucentBlack)
			end
			Font.print(fnt0, 20, 30, message, white)
		elseif response == 5 then
			Graphics.fillRect(15, 350, 30, 80, translucentBlack) 
			Font.print(fnt0, 20, 30, string.format("Max rating: %s",message), white) 
		else
			menu = false
			Graphics.fillRect(15, 325, 30, 80, translucentBlack) 
			Font.print(fnt0, 20, 30, message, white) 
		end
	else
		menu = false		-- Set menu visibility to false
	end
	-- Finish drawing
	Graphics.termBlend()
	Screen.flip()
	Screen.waitVblankStart()
end
