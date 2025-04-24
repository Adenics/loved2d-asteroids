-- Main Asteroids game module
local game = {}

-- Import dependencies
local helpers = require("utils.helpers")
local soundGen = require("utils.sound")
local Player = require("games.asteroids.player")
local Bullets = require("games.asteroids.bullets")
local Asteroids = require("games.asteroids.asteroids")
local UFO = require("games.asteroids.ufo")
local Particles = require("games.asteroids.particles")
local UI = require("games.asteroids.ui")

-- Game state and constants
local GAME_WIDTH = 800
local GAME_HEIGHT = 600
local score = 0
local lives = 3
local wave = 0
local gameState = "title" -- "title", "playing", "gameOver"
local isGameOver = false
local timeSinceLastUFO = 0
local ufoSpawnInterval = 18 -- Seconds between potential UFO spawns
local PLAYER_SPAWN_SAFE_ZONE_RADIUS = 180 -- Min distance asteroids spawn from player

-- Sounds
local sounds = {}
local thrustPlaying = false

-- Initialize the game
function game.load()
    -- Set master volume
    if love.audio then love.audio.setVolume(0.5) end
    
    -- Set line width
    love.graphics.setLineWidth(1.5)
    
    -- Load sounds
    sounds = soundGen.generateSounds()
    
    -- Initialize UI
    UI.load()
    
    -- Initialize modules with dependencies
    Player.init(sounds, GAME_WIDTH, GAME_HEIGHT)
    Bullets.init(sounds, GAME_WIDTH, GAME_HEIGHT)
    Asteroids.init(sounds, GAME_WIDTH, GAME_HEIGHT, PLAYER_SPAWN_SAFE_ZONE_RADIUS)
    UFO.init(sounds, GAME_WIDTH, GAME_HEIGHT)
    Particles.init(GAME_WIDTH, GAME_HEIGHT)
    
    -- Set initial game state
    gameState = "title"
    Player.resetState() -- Initialize player (invisible, not alive)
    
    print("Asteroids game loaded. State: " .. gameState)
end

-- Start a new game
function game.startGame()
    print("Starting New Game...")
    -- Reset scores, lives, wave
    score = 0
    lives = 3
    wave = 0
    
    -- Clear game objects
    Asteroids.clear()
    Bullets.clear()
    UFO.clear()
    Particles.clear()
    
    -- Reset player
    Player.resetState()
    
    -- Make player instantly visible and alive for the first spawn
    Player.setVisible(true)
    Player.setAlive(true)
    Player.setInvulnerable(true) -- Grant initial invulnerability
    
    -- Set game state
    gameState = "playing"
    isGameOver = false
    timeSinceLastUFO = 0
    
    -- Start first wave
    wave = 1
    Asteroids.spawnInitial(wave + 2)
    
    -- Ensure thrust sound is stopped
    if thrustPlaying then 
        if sounds.thrust then sounds.thrust:stop() end
        thrustPlaying = false 
    end
    
    print("First spawn complete (instant).")
end

-- Check for collisions between game objects
function game.checkCollisions()
    -- Check if player is even in a state where it can be hit
    if not Player.canBeHit() then return end
    
    -- Player vs Asteroids
    if Asteroids.checkPlayerCollision(Player) then
        Player.hit()
        return
    end
    
    -- Player vs UFO
    if UFO.checkPlayerCollision(Player) then
        Player.hit()
        return
    end
    
    -- Player Bullets vs Asteroids
    Bullets.checkAsteroidCollisions(Asteroids, function(asteroidIndex)
        local points = Asteroids.breakAsteroid(asteroidIndex)
        score = score + points
        
        -- Check if wave is cleared
        if gameState == "playing" and Asteroids.getCount() == 0 and not UFO.isActive() and Player.isFullyAlive() then
            wave = wave + 1
            print("Wave Cleared! Starting Wave " .. wave)
            Asteroids.spawnInitial(wave + 3)
        end
    end)
    
    -- Player Bullets vs UFO
    if Bullets.checkUFOCollision(UFO) then
        score = score + UFO.getPoints()
        UFO.destroy(true)
        
        -- Check if wave is cleared after UFO is destroyed
        if gameState == "playing" and Asteroids.getCount() == 0 and not UFO.isActive() and Player.isFullyAlive() then
            wave = wave + 1
            print("Wave Cleared (after UFO)! Starting Wave " .. wave)
            Asteroids.spawnInitial(wave + 3)
        end
    end
end

-- Update game state
function game.update(dt)
    dt = math.min(dt, 1/30) -- Clamp delta time to avoid large physics steps
    
    if gameState == "playing" then
        -- Handle player death and respawn animations
        Player.updateDeathAnimation(dt, function()
            -- Callback when death animation finishes
            lives = lives - 1
            if lives <= 0 then
                gameState = "gameOver"
                isGameOver = true
                if UFO.isActive() and sounds.ufo_flying and sounds.ufo_flying:isPlaying() then 
                    sounds.ufo_flying:stop() 
                end
            else
                Player.startRespawnAnimation()
            end
        end)
        
        Player.updateRespawnAnimation(dt)
        
        -- Update controllable player state only if fully alive
        if Player.isFullyAlive() then
            Player.update(dt)
            
            -- Manage thrust sound
            if Player.isThrusting() and not thrustPlaying then
                if sounds.thrust and not sounds.thrust:isPlaying() then sounds.thrust:play() end
                thrustPlaying = true
            elseif not Player.isThrusting() and thrustPlaying then
                if sounds.thrust then sounds.thrust:stop() end
                thrustPlaying = false
            end
        end
        
        -- Update other game objects
        Asteroids.update(dt)
        Bullets.update(dt)
        UFO.update(dt, Player)
        Particles.update(dt)
        
        -- Check collisions
        if Player.isFullyAlive() then
            game.checkCollisions()
        end
        
        -- Spawn UFO logic
        if not UFO.isActive() and Player.isFullyAlive() then
            timeSinceLastUFO = timeSinceLastUFO + dt
            if timeSinceLastUFO > ufoSpawnInterval then
                UFO.spawn()
                timeSinceLastUFO = 0
            end
        end
        
    elseif gameState == "gameOver" then
        -- Keep updating particles and UFO
        Player.updateDeathAnimation(dt) -- For fade-out effect
        Particles.update(dt)
        UFO.update(dt, nil) -- Pass nil player to prevent targeting
        
        -- Ensure thrust sound is stopped
        if thrustPlaying then 
            if sounds.thrust then sounds.thrust:stop() end
            thrustPlaying = false 
        end
    end
end

-- Draw the game
function game.draw()
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
    
    -- Set line style for retro look
    love.graphics.setLineStyle("rough")
    
    -- Define offsets for drawing wrapped objects near edges
    local offsets = {
        {0, 0}, {GAME_WIDTH, 0}, {-GAME_WIDTH, 0},
        {0, GAME_HEIGHT}, {0, -GAME_HEIGHT},
        {GAME_WIDTH, GAME_HEIGHT}, {-GAME_WIDTH, GAME_HEIGHT},
        {GAME_WIDTH, -GAME_HEIGHT}, {-GAME_WIDTH, -GAME_HEIGHT}
    }
    
    if gameState == "playing" or gameState == "gameOver" then
        -- Draw player (handles wrapping internally)
        Player.draw(offsets)
        
        -- Draw other objects with wrapping
        for _, offset in ipairs(offsets) do
            love.graphics.push()
            love.graphics.translate(offset[1], offset[2])
            
            Asteroids.draw()
            Bullets.draw()
            
            -- Draw UFO (only if not leaving)
            if UFO.isActive() and not UFO.isLeaving() then
                UFO.draw()
            end
            
            -- Draw particles
            Particles.draw()
            
            love.graphics.pop()
        end
        
        -- Draw the UFO separately if it's leaving
        if UFO.isActive() and UFO.isLeaving() then
            UFO.draw()
        end
    end
    
    -- Draw UI elements (score, lives, messages)
    UI.draw(gameState, score, lives, Player.isFullyAlive(), game.startGame)
    
    -- Restore default line style
    love.graphics.setLineStyle("smooth")
    
    -- Restore original graphics state
    love.graphics.pop()
end

-- Handle key press events
function game.keypressed(key)
    if key == "escape" then
        return -- Let main.lua handle escape
    end
    
    -- Start game from title screen
    if gameState == "title" and key == "return" then
        game.startGame()
    end
    
    -- Restart game from game over screen
    if gameState == "gameOver" and key == "r" then
        game.startGame()
    end
    
    -- Pass to player module if playing
    if gameState == "playing" and Player.isFullyAlive() then
        if key == "space" then
            Bullets.fire(Player.getPosition(), Player.getAngle(), Player.getVelocity())
        end
    end
end

-- Handle key release events
function game.keyreleased(key)
    -- Player module can handle this if needed
end

-- Handle window resize events
function game.resize(w, h)
    -- Nothing specific needed for resize
    print("Window resized to: " .. w .. "x" .. h)
end

-- Cleanup when exiting the game
function game.exit()
    -- Stop any ongoing sounds
    if sounds.thrust and sounds.thrust:isPlaying() then sounds.thrust:stop() end
    if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then sounds.ufo_flying:stop() end
    
    -- Additional cleanup could go here
    print("Exiting Asteroids game")
end

-- Expose some getters for other modules
function game.getGameDimensions()
    return GAME_WIDTH, GAME_HEIGHT
end

function game.getScore()
    return score
end

function game.getLives()
    return lives
end

function game.getWave()
    return wave
end

return game