-- UI module for Asteroids
local UI = {}

-- Module variables
local FONT_PATH = "assets/fonts/hyperspace.ttf"
local defaultFont, titleFont, promptFont, gameOverFont

-- Initialize module
function UI.load()
    local success
    
    -- Load fonts with fallbacks
    success, defaultFont = pcall(love.graphics.newFont, FONT_PATH, 18)
    if not success then
        defaultFont = love.graphics.newFont(18)
    end
    
    success, titleFont = pcall(love.graphics.newFont, FONT_PATH, 40)
    if not success then
        titleFont = defaultFont
    end
    
    success, promptFont = pcall(love.graphics.newFont, FONT_PATH, 20)
    if not success then
        promptFont = defaultFont
    end
    
    gameOverFont = titleFont
    
    -- Set nearest neighbor filtering for pixelated look
    if defaultFont.setFilter then defaultFont:setFilter("nearest", "nearest") end
    if titleFont.setFilter then titleFont:setFilter("nearest", "nearest") end
    if promptFont.setFilter then promptFont:setFilter("nearest", "nearest") end
end

-- Draw UI elements
function UI.draw(gameState, score, lives, playerActive, startGameFunc)
    love.graphics.setColor(1, 1, 1, 1)
    local currentFont = love.graphics.getFont()
    local gameWidth, gameHeight = love.graphics.getDimensions()
    
    -- Score and Lives (only during play and game over)
    if (gameState == "playing" or gameState == "gameOver") and defaultFont then
        love.graphics.setFont(defaultFont)
        
        -- Draw Score (top right)
        love.graphics.printf("SCORE " .. score, 10, 10, gameWidth - 20, "right")
        
        -- Draw Lives (top left)
        local livesToDraw = 0
        if lives > 0 then
            if playerActive then
                livesToDraw = lives - 1
            else
                livesToDraw = lives
            end
        end
        
        for i = 1, livesToDraw do
            local lifeX = 25 + (i * 25)
            local lifeY = 40
            love.graphics.push()
            love.graphics.translate(lifeX, lifeY)
            love.graphics.rotate(-math.pi / 2) -- Rotate to point up
            love.graphics.polygon("line", 8, 0, -5, -5, -5, 5) -- Simple triangle ship
            love.graphics.pop()
        end
    end
    
    -- State-specific messages
    if gameState == "title" then
        love.graphics.setFont(titleFont or defaultFont)
        love.graphics.printf("ASTEROIDS", 0, gameHeight / 3, gameWidth, "center")
        
        love.graphics.setFont(promptFont or defaultFont)
        love.graphics.printf("PRESS ENTER TO START", 0, gameHeight / 2 + 20, gameWidth, "center")
        love.graphics.printf("ARROWS ROTATE THRUST", 0, gameHeight - 80, gameWidth, "center")
        love.graphics.printf("SPACE SHOOT   H HYPERSPACE", 0, gameHeight - 50, gameWidth, "center")
        
    elseif gameState == "gameOver" then
        love.graphics.setFont(gameOverFont or defaultFont)
        love.graphics.printf("GAME OVER", 0, gameHeight / 2 - 60, gameWidth, "center")
        
        love.graphics.setFont(promptFont or defaultFont)
        love.graphics.printf("FINAL SCORE " .. score, 0, gameHeight / 2 + 0, gameWidth, "center")
        love.graphics.printf("PRESS R TO RESTART", 0, gameHeight / 2 + 40, gameWidth, "center")
    end
    
    love.graphics.setFont(currentFont)
    love.graphics.setColor(1, 1, 1, 1)
end

return UI