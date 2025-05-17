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
local isGameOver = false -- Redundant with gameState, but can be useful for specific checks
local timeSinceLastUFO = 0
local ufoSpawnInterval = 18 -- Seconds between potential UFO spawns
local PLAYER_SPAWN_SAFE_ZONE_RADIUS = 180 -- Min distance asteroids spawn from player

-- Sounds
local sounds = {}
local thrustPlaying = false -- Tracks if the thrust sound is currently meant to be playing

-- Initialize the game
function game.load()
    if love.audio then love.audio.setVolume(0.5) end
    love.graphics.setLineWidth(1.5)
    sounds = soundGen.generateSounds()
    UI.load()
    Player.init(sounds, GAME_WIDTH, GAME_HEIGHT)
    Bullets.init(sounds, GAME_WIDTH, GAME_HEIGHT)
    Asteroids.init(sounds, GAME_WIDTH, GAME_HEIGHT, PLAYER_SPAWN_SAFE_ZONE_RADIUS)
    UFO.init(sounds, GAME_WIDTH, GAME_HEIGHT)
    Particles.init(GAME_WIDTH, GAME_HEIGHT)
    gameState = "title"
    Player.resetState()
    print("Asteroids game loaded. State: " .. gameState)
end

-- Start a new game
function game.startGame()
    print("Starting New Game...")
    score = 0
    lives = 3
    wave = 0
    Asteroids.clear()
    Bullets.clear()
    UFO.clear()
    Particles.clear()
    Player.resetState()
    Player.setVisible(true)
    Player.setAlive(true)
    Player.setInvulnerable(true)
    gameState = "playing"
    isGameOver = false
    timeSinceLastUFO = 0
    wave = 1
    Asteroids.spawnInitial(wave + 2)
    if thrustPlaying then -- Ensure thrust sound is stopped from any previous state
        if sounds.thrust and sounds.thrust:isPlaying() then sounds.thrust:stop() end
        thrustPlaying = false
    end
    print("First spawn complete. Wave: " .. wave)
end

-- Check for collisions between game objects
function game.checkCollisions()
    if not Player.canBeHit() then return end

    if Asteroids.checkPlayerCollision(Player) then
        Player.hit()
        return
    end

    if UFO.checkPlayerCollision(Player) then
        Player.hit()
        return
    end

    Bullets.checkAsteroidCollisions(Asteroids, function(asteroidIndex)
        local points = Asteroids.breakAsteroid(asteroidIndex)
        score = score + points
        if gameState == "playing" and Asteroids.getCount() == 0 and not UFO.isActive() and Player.isFullyAlive() then
            wave = wave + 1
            print("Wave Cleared! Starting Wave " .. wave)
            Asteroids.spawnInitial(wave + 3)
        end
    end)

    if Bullets.checkUFOCollision(UFO) then
        score = score + UFO.getPoints()
        UFO.destroy(true)
        if gameState == "playing" and Asteroids.getCount() == 0 and not UFO.isActive() and Player.isFullyAlive() then
            wave = wave + 1
            print("Wave Cleared (after UFO)! Starting Wave " .. wave)
            Asteroids.spawnInitial(wave + 3)
        end
    end
end

-- Update game state
function game.update(dt)
    dt = math.min(dt, 1/30) -- Clamp delta time

    if gameState == "playing" then
        Player.updateDeathAnimation(dt, function()
            lives = lives - 1
            if lives <= 0 then
                gameState = "gameOver"
                isGameOver = true
                if sounds.gameOver then sounds.gameOver:play() end
                if UFO.isActive() and sounds.ufo_flying and sounds.ufo_flying:isPlaying() then
                    sounds.ufo_flying:stop()
                end
                -- Ensure thrust sound is stopped on game over transition
                if thrustPlaying then
                    if sounds.thrust and sounds.thrust:isPlaying() then sounds.thrust:stop() end
                    thrustPlaying = false
                    print("Thrust sound stopped due to game over.")
                end
            else
                Player.startRespawnAnimation()
            end
        end)

        Player.updateRespawnAnimation(dt)

        if Player.isFullyAlive() then
            Player.update(dt)
            -- Manage thrust sound
            if Player.isThrusting() and not thrustPlaying then
                if sounds.thrust and not sounds.thrust:isPlaying() then sounds.thrust:play() end
                thrustPlaying = true
            elseif not Player.isThrusting() and thrustPlaying then
                if sounds.thrust and sounds.thrust:isPlaying() then sounds.thrust:stop() end
                thrustPlaying = false
            end
        else
            -- Player is not fully alive (e.g., dying, respawning, or just hit)
            -- Ensure thrust sound is stopped if it was playing.
            if thrustPlaying then
                if sounds.thrust and sounds.thrust:isPlaying() then
                    sounds.thrust:stop()
                    print("Thrust sound stopped because player is not fully alive.")
                end
                thrustPlaying = false
            end
        end

        Asteroids.update(dt)
        Bullets.update(dt)
        UFO.update(dt, Player)
        Particles.update(dt)

        if Player.isFullyAlive() or Player.canBeHit() then
            game.checkCollisions()
        end

        if not UFO.isActive() and Player.isFullyAlive() then
            timeSinceLastUFO = timeSinceLastUFO + dt
            if timeSinceLastUFO > ufoSpawnInterval then
                UFO.spawn()
                timeSinceLastUFO = 0
            end
        end

    elseif gameState == "gameOver" then
        Player.updateDeathAnimation(dt)
        Particles.update(dt)
        UFO.update(dt, nil)
        -- Ensure thrust sound is stopped in game over state (double check)
        if thrustPlaying then
            if sounds.thrust and sounds.thrust:isPlaying() then sounds.thrust:stop() end
            thrustPlaying = false
            print("Thrust sound stopped (game over update loop).")
        end
    end
end

-- Draw the game
function game.draw()
    local actualW, actualH = love.graphics.getDimensions()
    local scaleX = actualW / GAME_WIDTH
    local scaleY = actualH / GAME_HEIGHT
    local scale = math.min(scaleX, scaleY)
    local offsetX = (actualW - GAME_WIDTH * scale) / 2
    local offsetY = (actualH - GAME_HEIGHT * scale) / 2

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)
    love.graphics.setLineStyle("rough")

    local offsets = {
        {0, 0}, {GAME_WIDTH, 0}, {-GAME_WIDTH, 0},
        {0, GAME_HEIGHT}, {0, -GAME_HEIGHT},
        {GAME_WIDTH, GAME_HEIGHT}, {-GAME_WIDTH, GAME_HEIGHT},
        {GAME_WIDTH, -GAME_HEIGHT}, {-GAME_WIDTH, -GAME_HEIGHT}
    }

    if gameState == "playing" or gameState == "gameOver" then
        Player.draw(offsets)
        for _, offsetPair in ipairs(offsets) do
            love.graphics.push()
            love.graphics.translate(offsetPair[1], offsetPair[2])
            Asteroids.draw()
            Bullets.draw()
            if UFO.isActive() and not UFO.isLeaving() then UFO.draw() end
            Particles.draw()
            love.graphics.pop()
        end
        if UFO.isActive() and UFO.isLeaving() then UFO.draw() end
    end

    UI.draw(gameState, score, lives, Player.isFullyAlive(), game.startGame)
    love.graphics.setLineStyle("smooth")
    love.graphics.pop()
end

-- Handle key press events
function game.keypressed(key)
    if key == "escape" then return end

    if gameState == "title" and (key == "return" or key == "kpenter") then
        game.startGame()
    end

    if gameState == "gameOver" and key == "r" then
        game.startGame()
    end

    if gameState == "playing" and Player.isFullyAlive() then
        if key == "space" then
            Bullets.fire(Player)
        end
    end
end

function game.keyreleased(key)
    -- Not currently used for player actions
end

function game.resize(w, h)
    print("Window resized to: " .. w .. "x" .. h .. ". Game will scale.")
end

function game.exit()
    if sounds.thrust and sounds.thrust:isPlaying() then sounds.thrust:stop() end
    if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then sounds.ufo_flying:stop() end
    print("Exiting Asteroids game state")
end

function game.getGameDimensions() return GAME_WIDTH, GAME_HEIGHT end
function game.getScore() return score end
function game.getLives() return lives end
function game.getWave() return wave end

return game