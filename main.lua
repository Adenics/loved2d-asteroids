-- Main entry point for the arcade system
-- Loads and initializes the menu

-- Global variables
gameState = "menu" -- "menu", "playing"
currentGame = nil  -- Reference to the currently loaded game

-- Debug function to help trace errors
function debug_print(msg)
    print("[DEBUG] " .. tostring(msg))
end

-- Check if a file exists
function file_exists(path)
    local file = io.open(path, "r")
    if file then file:close() return true else return false end
end

function love.load()
    debug_print("Starting application...")
    
    -- Set random seed
    love.math.setRandomSeed(os.time())
    
    -- Set default background
    love.graphics.setBackgroundColor(0, 0, 0)
    
    -- Check if required directories and files exist
    debug_print("Checking directory structure...")
    if not love.filesystem.getInfo("menu.lua") then
        debug_print("ERROR: menu.lua not found in root directory!")
    end
    
    if not love.filesystem.getInfo("games") then
        debug_print("ERROR: 'games' directory not found!")
    end
    
    if love.filesystem.getInfo("games") then
        if not love.filesystem.getInfo("games/asteroids") then
            debug_print("ERROR: 'games/asteroids' directory not found!")
        elseif not love.filesystem.getInfo("games/asteroids/game.lua") then
            debug_print("ERROR: 'games/asteroids/game.lua' not found!")
        end
    end
    
    if not love.filesystem.getInfo("utils") then
        debug_print("ERROR: 'utils' directory not found!")
    end
    
    -- Try to load menu
    debug_print("Attempting to load menu...")
    local success, result = pcall(require, "menu")
    if success then
        menu = result
        menu.load()
        debug_print("Menu loaded successfully")
    else
        debug_print("MENU LOAD ERROR: " .. tostring(result))
        -- Create a minimal menu if proper menu can't be loaded
        menu = {
            load = function() end,
            update = function() end,
            draw = function()
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("ERROR LOADING MENU: " .. tostring(result), 50, 50)
                love.graphics.print("Please check the console output for details", 50, 70)
            end,
            keypressed = function() end
        }
    end
end

function love.update(dt)
    if gameState == "menu" then
        menu.update(dt)
    elseif gameState == "playing" and currentGame then
        currentGame.update(dt)
    end
end

function love.draw()
    if gameState == "menu" then
        menu.draw()
    elseif gameState == "playing" and currentGame then
        currentGame.draw()
    else
        -- Fallback if no state is valid
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("ERROR: Invalid game state", 50, 50)
    end
end

function love.keypressed(key)
    if key == "escape" then
        if gameState == "playing" and currentGame then
            -- Return to menu
            if currentGame.exit then currentGame.exit() end
            currentGame = nil
            gameState = "menu"
        else
            love.event.quit()
        end
    elseif gameState == "menu" then
        menu.keypressed(key)
    elseif gameState == "playing" and currentGame then
        currentGame.keypressed(key)
    end
end

function love.keyreleased(key)
    if gameState == "playing" and currentGame then
        currentGame.keyreleased(key)
    end
end

function love.resize(w, h)
    if gameState == "playing" and currentGame and currentGame.resize then
        currentGame.resize(w, h)
    end
end

-- Function to load and switch to a game
function loadGame(gameName)
    debug_print("Attempting to load game: " .. gameName)
    
    if gameState == "playing" and currentGame then
        if currentGame.exit then currentGame.exit() end
    end
    
    -- Try to load the game module
    local success, game = pcall(require, "games." .. gameName .. ".game")
    
    if success then
        debug_print("Game module loaded successfully")
        currentGame = game
        
        success, err = pcall(function() currentGame.load() end)
        if success then
            debug_print("Game initialized successfully")
            gameState = "playing"
            return true
        else
            debug_print("ERROR initializing game: " .. tostring(err))
            currentGame = nil
            return false
        end
    else
        debug_print("ERROR loading game module: " .. tostring(game))
        return false
    end
end