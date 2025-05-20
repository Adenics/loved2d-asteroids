local UI = {}

local FONT_PATH = "assets/fonts/hyperspace.ttf" 
local defaultFont, titleFont, promptFont, gameOverFont

function UI.load()
    local success

    success, defaultFont = pcall(love.graphics.newFont, FONT_PATH, 18)
    if not success then
        print("Warning: Could not load font at " .. FONT_PATH .. ". Using default font for size 18.")
        defaultFont = love.graphics.newFont(18) 
    end

    success, titleFont = pcall(love.graphics.newFont, FONT_PATH, 40)
    if not success then
        print("Warning: Could not load font at " .. FONT_PATH .. ". Using default font for size 40.")
        titleFont = defaultFont 
    end

    success, promptFont = pcall(love.graphics.newFont, FONT_PATH, 20)
    if not success then
        print("Warning: Could not load font at " .. FONT_PATH .. ". Using default font for size 20.")
        promptFont = defaultFont 
    end

    gameOverFont = titleFont 

    if defaultFont and defaultFont.setFilter then defaultFont:setFilter("nearest", "nearest") end
    if titleFont and titleFont.setFilter then titleFont:setFilter("nearest", "nearest") end
    if promptFont and promptFont.setFilter then promptFont:setFilter("nearest", "nearest") end
end

function UI.draw(gameState, score, lives, playerActive, startGameFunc)
    love.graphics.setColor(1, 1, 1, 1) 
    local currentFont = love.graphics.getFont() 

    local screenWidth, screenHeight = love.graphics.getDimensions()

    if (gameState == "playing" or gameState == "gameOver") and defaultFont then
        love.graphics.setFont(defaultFont)

        love.graphics.printf("SCORE " .. score, 10, 10, screenWidth - 20, "right")

        local livesToDraw = lives

        for i = 1, livesToDraw do

            local lifeX = 20 + (i * 25) 
            local lifeY = 25            
            love.graphics.push()
            love.graphics.translate(lifeX, lifeY)
            love.graphics.rotate(-math.pi / 2) 

            love.graphics.polygon("line", 8, 0, -5, -5, -5, 5)
            love.graphics.pop()
        end
    end

    if gameState == "title" then
        love.graphics.setFont(titleFont or defaultFont)
        love.graphics.printf("ASTEROIDS", 0, screenHeight / 3, screenWidth, "center")

        love.graphics.setFont(promptFont or defaultFont)
        love.graphics.printf("PRESS ENTER TO START", 0, screenHeight / 2 + 30, screenWidth, "center")
        love.graphics.printf("ARROWS ROTATE & THRUST", 0, screenHeight - 90, screenWidth, "center")
        love.graphics.printf("SPACE SHOOT   H HYPERSPACE", 0, screenHeight - 60, screenWidth, "center")

    elseif gameState == "gameOver" then
        love.graphics.setFont(gameOverFont or defaultFont) 
        love.graphics.printf("GAME OVER", 0, screenHeight / 2 - 70, screenWidth, "center")

        love.graphics.setFont(promptFont or defaultFont)
        love.graphics.printf("FINAL SCORE " .. score, 0, screenHeight / 2 - 10, screenWidth, "center")
        love.graphics.printf("PRESS R TO RESTART", 0, screenHeight / 2 + 30, screenWidth, "center")
    end

    love.graphics.setFont(currentFont) 
    love.graphics.setColor(1, 1, 1, 1) 
end

return UI