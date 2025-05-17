-- UI module for Asteroids
local UI = {}

-- Module variables
local FONT_PATH = "assets/fonts/hyperspace.ttf" -- Ensure this path is correct relative to your main.lua or executable
local defaultFont, titleFont, promptFont, gameOverFont

-- Initialize module
function UI.load()
    local success

    -- Load fonts with fallbacks
    -- Attempt to load the custom font, fall back to default LÖVE font if not found
    success, defaultFont = pcall(love.graphics.newFont, FONT_PATH, 18)
    if not success then
        print("Warning: Could not load font at " .. FONT_PATH .. ". Using default font for size 18.")
        defaultFont = love.graphics.newFont(18) -- Default LÖVE font
    end

    success, titleFont = pcall(love.graphics.newFont, FONT_PATH, 40)
    if not success then
        print("Warning: Could not load font at " .. FONT_PATH .. ". Using default font for size 40.")
        titleFont = defaultFont -- Fallback to already loaded/defaulted font
    end

    success, promptFont = pcall(love.graphics.newFont, FONT_PATH, 20)
    if not success then
        print("Warning: Could not load font at " .. FONT_PATH .. ". Using default font for size 20.")
        promptFont = defaultFont -- Fallback
    end

    gameOverFont = titleFont -- Use the same font as the title for "GAME OVER"

    -- Set nearest neighbor filtering for a crisp, pixelated look if the custom font is used
    -- This check ensures setFilter is only called on actual Font objects
    if defaultFont and defaultFont.setFilter then defaultFont:setFilter("nearest", "nearest") end
    if titleFont and titleFont.setFilter then titleFont:setFilter("nearest", "nearest") end
    if promptFont and promptFont.setFilter then promptFont:setFilter("nearest", "nearest") end
end

-- Draw UI elements
-- playerActive is Player.isFullyAlive() passed from game.lua
function UI.draw(gameState, score, lives, playerActive, startGameFunc)
    love.graphics.setColor(1, 1, 1, 1) -- Default to white color
    local currentFont = love.graphics.getFont() -- Store current font to restore later
    
    -- Use the game's configured dimensions for UI layout, not love.graphics.getDimensions() directly
    -- This ensures UI scales correctly with the game's internal resolution.
    -- Assuming game.lua has GAME_WIDTH and GAME_HEIGHT constants it uses for its world.
    -- For this UI module, we'll use the love.graphics.getDimensions() for screen-space UI,
    -- but if the game is scaled, these texts will be drawn over the scaled game.
    -- The main game.draw() handles the scaling of the game world itself.
    local screenWidth, screenHeight = love.graphics.getDimensions()


    -- Score and Lives (only during play and game over)
    if (gameState == "playing" or gameState == "gameOver") and defaultFont then
        love.graphics.setFont(defaultFont)

        -- Draw Score (top right of the screen)
        -- Using screenWidth for positioning relative to the window edge.
        love.graphics.printf("SCORE " .. score, 10, 10, screenWidth - 20, "right")

        -- Draw Lives (top left of the screen)
        -- The number of lives to draw is now simply the 'lives' variable.
        local livesToDraw = lives

        -- Loop to draw each life icon
        -- The icons represent the total lives remaining, including the current one.
        for i = 1, livesToDraw do
            -- Position each life icon. Adjust spacing as needed.
            local lifeX = 20 + (i * 25) -- Start further left, consistent spacing
            local lifeY = 25            -- Y position for life icons
            love.graphics.push()
            love.graphics.translate(lifeX, lifeY)
            love.graphics.rotate(-math.pi / 2) -- Rotate ship icon to point upwards
            -- Simple triangle for the ship icon: (nose), (left wing), (right wing)
            love.graphics.polygon("line", 8, 0, -5, -5, -5, 5)
            love.graphics.pop()
        end
    end

    -- State-specific messages (centered on screen)
    if gameState == "title" then
        love.graphics.setFont(titleFont or defaultFont)
        love.graphics.printf("ASTEROIDS", 0, screenHeight / 3, screenWidth, "center")

        love.graphics.setFont(promptFont or defaultFont)
        love.graphics.printf("PRESS ENTER TO START", 0, screenHeight / 2 + 30, screenWidth, "center")
        love.graphics.printf("ARROWS ROTATE & THRUST", 0, screenHeight - 90, screenWidth, "center")
        love.graphics.printf("SPACE SHOOT   H HYPERSPACE", 0, screenHeight - 60, screenWidth, "center")

    elseif gameState == "gameOver" then
        love.graphics.setFont(gameOverFont or defaultFont) -- Use the larger font for "GAME OVER"
        love.graphics.printf("GAME OVER", 0, screenHeight / 2 - 70, screenWidth, "center")

        love.graphics.setFont(promptFont or defaultFont)
        love.graphics.printf("FINAL SCORE " .. score, 0, screenHeight / 2 - 10, screenWidth, "center")
        love.graphics.printf("PRESS R TO RESTART", 0, screenHeight / 2 + 30, screenWidth, "center")
    end

    love.graphics.setFont(currentFont) -- Restore the original font
    love.graphics.setColor(1, 1, 1, 1) -- Reset color just in case
end

return UI