-- Main menu system
local menu = {}

-- Local variables
local GAME_WIDTH = 800
local GAME_HEIGHT = 600
local titleFont, menuFont
local FONT_PATH = "assets/fonts/hyperspace.ttf" -- Ensure this path is correct
local selectedIndex = 1
local menuItems = {
    { name = "Asteroids", id = "asteroids" },
    -- Add more games here as needed
    { name = "Exit", id = "exit" }
}
local titleColor = {1, 1, 1, 1}      -- White
local menuItemColor = {1, 1, 1, 1}   -- White
local selectedItemColor = {1, 0.6, 0.6, 1} -- Light Reddish for selection highlight

-- Store loaded sounds locally within the menu module
local menuSounds = nil

function menu.load()
    -- Load fonts
    local success
    success, titleFont = pcall(love.graphics.newFont, FONT_PATH, 48)
    if not success then
        print("Warning: Menu title font not found at " .. FONT_PATH .. ". Using default.")
        titleFont = love.graphics.newFont(48) -- Fallback to default LÖVE font
    end

    success, menuFont = pcall(love.graphics.newFont, FONT_PATH, 24)
    if not success then
        print("Warning: Menu item font not found at " .. FONT_PATH .. ". Using default.")
        menuFont = love.graphics.newFont(24) -- Fallback
    end

    -- Set nearest neighbor filtering for a crisp, pixelated look if custom fonts loaded
    if titleFont and titleFont.setFilter then titleFont:setFilter("nearest", "nearest") end
    if menuFont and menuFont.setFilter then menuFont:setFilter("nearest", "nearest") end

    -- Load sounds for the menu
    -- This will generate all sounds defined in sound.lua, including menu_select
    local soundGen = require("utils.sound")
    menuSounds = soundGen.generateSounds()
    if menuSounds then
        print("Menu sounds loaded.")
    else
        print("Warning: Failed to load menu sounds.")
    end
end

function menu.update(dt)
    -- Menu animations or effects could go here if needed in the future
end

function menu.draw()
    -- Calculate scaling to fit game area into window, maintaining aspect ratio
    local actualW, actualH = love.graphics.getDimensions()
    local scaleX = actualW / GAME_WIDTH
    local scaleY = actualH / GAME_HEIGHT
    local scale = math.min(scaleX, scaleY) -- Use the smaller scale factor to fit

    -- Calculate offsets to center the scaled game area
    local offsetX = (actualW - GAME_WIDTH * scale) / 2
    local offsetY = (actualH - GAME_HEIGHT * scale) / 2

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    -- Draw title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(titleColor)
    love.graphics.printf("ARCADE", 0, GAME_HEIGHT * 0.2, GAME_WIDTH, "center")

    -- Draw menu items
    love.graphics.setFont(menuFont)
    local itemHeight = 40 -- Spacing between menu items
    local menuY = GAME_HEIGHT * 0.4 -- Starting Y position for the menu items

    for i, item in ipairs(menuItems) do
        if i == selectedIndex then
            love.graphics.setColor(selectedItemColor)
            love.graphics.printf("> " .. item.name .. " <", 0, menuY + (i-1) * itemHeight, GAME_WIDTH, "center")
        else
            love.graphics.setColor(menuItemColor)
            love.graphics.printf(item.name, 0, menuY + (i-1) * itemHeight, GAME_WIDTH, "center")
        end
    end

    -- Draw instructions at the bottom
    love.graphics.setColor(1, 1, 1, 0.7) -- Slightly transparent white for instructions
    love.graphics.printf("UP/DOWN: Select  ENTER: Choose", 0, GAME_HEIGHT * 0.85, GAME_WIDTH, "center")

    love.graphics.pop() -- Restore graphics state
end

function menu.keypressed(key)
    local previousIndex = selectedIndex

    if key == "up" then
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then
            selectedIndex = #menuItems -- Wrap around to the last item
        end
    elseif key == "down" then
        selectedIndex = selectedIndex + 1
        if selectedIndex > #menuItems then
            selectedIndex = 1 -- Wrap around to the first item
        end
    elseif key == "return" or key == "space" or key == "kpenter" then
        local selected = menuItems[selectedIndex]
        if selected.id == "exit" then
            love.event.quit() -- Quit the application
        else
            -- This global function is defined in main.lua
            -- It handles switching from the menu state to the game state
            if loadGame then
                loadGame(selected.id)
            else
                print("ERROR: loadGame function not found. Cannot switch to game.")
            end
        end
        return -- Don't play selection sound on enter/select
    end

    -- Play selection change sound if index changed
    if selectedIndex ~= previousIndex then
        if menuSounds and menuSounds.menu_select then
            -- It's good practice to clone sounds that might be played rapidly
            -- or if the original source might be stopped/manipulated elsewhere.
            -- For simple beeps, direct play is often fine.
            local soundToPlay = menuSounds.menu_select:clone()
            soundToPlay:setVolume(0.7) -- Adjust volume if needed
            soundToPlay:play()
        else
            print("Debug: Menu select sound not available or not played.")
        end
    end
end

return menu