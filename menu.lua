-- Main menu system
local menu = {}

-- Local variables
local GAME_WIDTH = 800
local GAME_HEIGHT = 600
local titleFont, menuFont
local FONT_PATH = "assets/fonts/hyperspace.ttf"
local selectedIndex = 1
local menuItems = {
    { name = "Asteroids", id = "asteroids" },
    -- Add more games here
    { name = "Exit", id = "exit" }
}
local titleColor = {1, 1, 1, 1}
local menuItemColor = {1, 1, 1, 1}
local selectedItemColor = {1, 0.5, 0.5, 1}

function menu.load()
    -- Load fonts
    local success
    success, titleFont = pcall(love.graphics.newFont, FONT_PATH, 48)
    if not success then
        titleFont = love.graphics.newFont(48)
    end
    
    success, menuFont = pcall(love.graphics.newFont, FONT_PATH, 24)
    if not success then
        menuFont = love.graphics.newFont(24)
    end
    
    -- Set filterings for pixelated look
    if titleFont.setFilter then titleFont:setFilter("nearest", "nearest") end
    if menuFont.setFilter then menuFont:setFilter("nearest", "nearest") end
end

function menu.update(dt)
    -- Menu animations or effects could go here
end

function menu.draw()
    -- Calculate scaling to fit game area into window
    local actualW, actualH = love.graphics.getDimensions()
    local scaleX = actualW / GAME_WIDTH
    local scaleY = actualH / GAME_HEIGHT
    local scale = math.min(scaleX, scaleY)
    
    -- Calculate offsets to center the scaled game area
    local offsetX = (actualW - GAME_WIDTH * scale) / 2
    local offsetY = (actualH - GAME_HEIGHT * scale) / 2
    
    -- Apply scaling and translation
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)
    
    -- Draw title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(titleColor)
    love.graphics.printf("ARCADE", 0, GAME_HEIGHT * 0.2, GAME_WIDTH, "center")
    
    -- Draw menu items
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
    
    -- Draw instructions
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("UP/DOWN: Select  ENTER: Choose", 0, GAME_HEIGHT * 0.8, GAME_WIDTH, "center")
    
    love.graphics.pop()
end

function menu.keypressed(key)
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
    elseif key == "return" or key == "space" then
        local selected = menuItems[selectedIndex]
        
        if selected.id == "exit" then
            love.event.quit()
        else
            loadGame(selected.id)
        end
    end
end

return menu