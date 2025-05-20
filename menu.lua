local menu = {}

local GAME_WIDTH = 800
local GAME_HEIGHT = 600
local titleFont, menuFont
local FONT_PATH = "assets/fonts/hyperspace.ttf" 
local selectedIndex = 1
local menuItems = {
    { name = "Asteroids", id = "asteroids" },

    { name = "Exit", id = "exit" }
}
local titleColor = {1, 1, 1, 1}      
local menuItemColor = {1, 1, 1, 1}   
local selectedItemColor = {1, 0.6, 0.6, 1} 

local menuSounds = nil

function menu.load()

    local success
    success, titleFont = pcall(love.graphics.newFont, FONT_PATH, 48)
    if not success then
        print("Warning: Menu title font not found at " .. FONT_PATH .. ". Using default.")
        titleFont = love.graphics.newFont(48) 
    end

    success, menuFont = pcall(love.graphics.newFont, FONT_PATH, 24)
    if not success then
        print("Warning: Menu item font not found at " .. FONT_PATH .. ". Using default.")
        menuFont = love.graphics.newFont(24) 
    end

    if titleFont and titleFont.setFilter then titleFont:setFilter("nearest", "nearest") end
    if menuFont and menuFont.setFilter then menuFont:setFilter("nearest", "nearest") end

    local soundGen = require("utils.sound")
    menuSounds = soundGen.generateSounds()
    if menuSounds then
        print("Menu sounds loaded.")
    else
        print("Warning: Failed to load menu sounds.")
    end
end

function menu.update(dt)

end

function menu.draw()

    local actualW, actualH = love.graphics.getDimensions()
    local scaleX = actualW / GAME_WIDTH
    local scaleY = actualH / GAME_HEIGHT
    local scale = math.min(scaleX, scaleY) 

    local offsetX = (actualW - GAME_WIDTH * scale) / 2
    local offsetY = (actualH - GAME_HEIGHT * scale) / 2

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(titleColor)
    love.graphics.printf("ARCADE", 0, GAME_HEIGHT * 0.2, GAME_WIDTH, "center")

    love.graphics.setFont(menuFont)
    local itemHeight = 40 
    local menuY = GAME_HEIGHT * 0.4 

    for i, item in ipairs(menuItems) do
        if i == selectedIndex then
            love.graphics.setColor(selectedItemColor)
            love.graphics.printf("> " .. item.name .. " <", 0, menuY + (i-1) * itemHeight, GAME_WIDTH, "center")
        else
            love.graphics.setColor(menuItemColor)
            love.graphics.printf(item.name, 0, menuY + (i-1) * itemHeight, GAME_WIDTH, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 0.7) 
    love.graphics.printf("UP/DOWN: Select  ENTER: Choose", 0, GAME_HEIGHT * 0.85, GAME_WIDTH, "center")

    love.graphics.pop() 
end

function menu.keypressed(key)
    local previousIndex = selectedIndex

    if key == "up" then
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then
            selectedIndex = #menuItems 
        end
    elseif key == "down" then
        selectedIndex = selectedIndex + 1
        if selectedIndex > #menuItems then
            selectedIndex = 1 
        end
    elseif key == "return" or key == "space" or key == "kpenter" then
        local selected = menuItems[selectedIndex]
        if selected.id == "exit" then
            love.event.quit() 
        else

            if loadGame then
                loadGame(selected.id)
            else
                print("ERROR: loadGame function not found. Cannot switch to game.")
            end
        end
        return 
    end

    if selectedIndex ~= previousIndex then
        if menuSounds and menuSounds.menu_select then

            local soundToPlay = menuSounds.menu_select:clone()
            soundToPlay:setVolume(0.7) 
            soundToPlay:play()
        else
            print("Debug: Menu select sound not available or not played.")
        end
    end
end

return menu