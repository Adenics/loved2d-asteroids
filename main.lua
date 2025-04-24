--[[
Loved2D Asteroids Game
Based on the classic arcade game.

Controls:
Left/Right Arrows: Rotate Ship
Up Arrow: Thrust
Spacebar: Fire Bullet
H: Hyperspace Jump (with cooldown)
Enter: Start Game (from title screen)
R: Restart Game (from game over screen)
Escape: Quit Game
--]]

-- Game constants
local GAME_WIDTH = 800
local GAME_HEIGHT = 600

-- Game state variables
local player = {}
local asteroids = {}
local bullets = {}
local ufo = nil -- UFO object
local particles = {} -- For explosion effects

local score = 0
local lives = 3
local wave = 0
local gameState = "title" -- "title", "playing", "gameOver"
local isGameOver = false
local timeSinceLastUFO = 0
local ufoSpawnInterval = 18 -- Seconds between potential UFO spawns
local ufoActive = false

-- Player constants
local PLAYER_ROTATION_SPEED = 4.5 -- Radians per second
local PLAYER_THRUST = 375 -- Acceleration units
local PLAYER_FRICTION = 0.985 -- Multiplier applied each frame to velocity
local PLAYER_MAX_SPEED = 580 -- Maximum velocity
local PLAYER_GUN_COOLDOWN = 0.2 -- Seconds between shots
local PLAYER_INVULNERABILITY_TIME = 2.0 -- Seconds after respawn
local PLAYER_HYPERSPACE_COOLDOWN = 5.0 -- Seconds between hyperspace jumps
local PLAYER_DEATH_ANIM_DURATION = 2.0 -- Seconds for death animation (segments flying)
local PLAYER_RESPAWN_ANIM_DURATION = 1.0 -- Seconds for respawn animation (segments returning)
local PLAYER_SEGMENT_MAX_SPEED = 150 -- Max speed for flying segments during death anim
local PLAYER_SEGMENT_MAX_SPIN = 3.0 -- Max rotation speed for flying segments
local GAME_OVER_FADE_DURATION = 1.5 -- Seconds for segments to fade out on game over
local PLAYER_SPAWN_SAFE_ZONE_RADIUS = 180 -- Min distance asteroids spawn from player
local playerGunTimer = 0
local playerInvulnerableTimer = 0
local playerHyperspaceTimer = 0

-- Bullet constants
local BULLET_SPEED = 450
local BULLET_LIFETIME = 1.2 -- Seconds
local MAX_BULLETS = 4 -- Max player bullets on screen

-- Asteroid constants
local ASTEROID_SPEED_MIN = 30
local ASTEROID_SPEED_MAX = 90
local ASTEROID_POINTS = { [3] = 20, [2] = 50, [1] = 100 } -- Points per size (large, medium, small)
local ASTEROID_SIZES = { large = 35, medium = 20, small = 10 } -- Radii (Used for spawning distance, less for collision now)
local ASTEROID_SIZE_MAP = { [3] = ASTEROID_SIZES.large, [2] = ASTEROID_SIZES.medium, [1] = ASTEROID_SIZES.small }
local ASTEROID_VERTICES = 12 -- Average number of vertices
local ASTEROID_IRREGULARITY = 0.6 -- How much vertex distance varies (0=circle, 1=very jagged)

-- UFO constants
local UFO_SPEED = 110 -- Base horizontal speed
local UFO_FIRE_RATE = 1.4 -- Seconds between shots (average)
local UFO_BULLET_SPEED = 270
local UFO_POINTS = 200
local UFO_MIN_LIFETIME = 8 -- Min seconds UFO stays on screen before leaving
local UFO_MAX_LIFETIME = 15 -- Max seconds UFO stays on screen before leaving
local ufoBullets = {}
local ufoFireTimer = 0
local ufoDirectionChangeTimer = 0
local UFO_DIRECTION_CHANGE_INTERVAL = 2.0 -- Seconds between potential direction changes
local UFO_LEAVING_SPEED_MULTIPLIER = 3.0 -- How much faster it moves when leaving

-- Particle constants
local PARTICLE_LIFETIME = 0.5 -- Seconds
local PARTICLE_SPEED = 150 -- Max speed

-- Assets
local sounds = {}
local thrustPlaying = false -- Track if thrust sound is active

-- Fonts (paths relative to main.lua)
local defaultFont = nil
local titleFont = nil
local promptFont = nil
local gameOverFont = nil
local FONT_PATH = "font/hyperspace.ttf" -- Make sure this font file exists in a 'font' subfolder

-- Utility Functions ---------------------------------------------------------

-- Wraps a value around a given range (toroidal coordinates)
function wrap(value, min_val, max_val)
    local range = max_val - min_val
    if range == 0 then return min_val end
    -- The double modulo handles negative values correctly
    return ((value - min_val) % range + range) % range + min_val
end

-- Calculates distance between two points
function distance(x1, y1, x2, y2)
    -- Guard against nil inputs which cause errors
    if x1 == nil or y1 == nil or x2 == nil or y2 == nil then return math.huge end
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Checks collision between two *circular* objects, considering screen wrap (Used for Player/UFO vs UFO Bullets/UFO Body)
function checkCircleCollision(obj1, obj2)
    -- Ensure objects and their positions/radii are valid
    if not obj1 or not obj2 or not obj1.x or not obj1.y or not obj2.x or not obj2.y then return false end
    local r1 = obj1.radius or 0
    local r2 = obj2.radius or 0
    -- Use a small minimum radius to avoid issues with radius 0 checks during transitions
    local min_radius = 1
    if r1 < min_radius or r2 < min_radius then return false end

    -- Calculate wrapped distance (shortest distance considering screen edges)
    local dx_wrap = math.abs(obj1.x - obj2.x)
    local dy_wrap = math.abs(obj1.y - obj2.y)
    local dx = math.min(dx_wrap, GAME_WIDTH - dx_wrap)
    local dy = math.min(dy_wrap, GAME_HEIGHT - dy_wrap)

    -- Check if distance is less than sum of radii
    return (dx * dx + dy * dy) < (r1 + r2)^2
end

-- Function to check if a point (px, py) is inside a polygon defined by vertices table { {x=,y=}, {x=,y=}, ...}
-- Uses the ray casting algorithm. Returns true if the point is inside or on the boundary.
function pointInPolygon(poly, px, py)
    local crossings = 0
    local n = #poly
    if n < 3 then return false end -- Need at least 3 vertices

    for i = 1, n do
        local p1 = poly[i]
        local p2 = poly[i % n + 1] -- Next vertex, wraps around

        -- Check if point lies exactly on a vertex
        if px == p1.x and py == p1.y then
            return true
        end

        -- Check if the point's y is between the edge's y-coordinates (exclusive on one end for robustness)
        local y_between = (p1.y <= py and py < p2.y) or (p2.y <= py and py < p1.y)

        if y_between then
            -- Calculate the edge's x-intercept at the point's y level
            -- Avoid division by zero for vertical lines (should be caught by y-check if horizontal)
            if p2.y - p1.y ~= 0 then
                 -- Calculate intersection X coordinate using linear interpolation formula
                 local intersectX = (py - p1.y) * (p2.x - p1.x) / (p2.y - p1.y) + p1.x

                 -- If the point is to the left of the intersection, increment crossings
                 if px < intersectX then
                     crossings = crossings + 1
                 -- Check if the point lies exactly on a non-horizontal edge segment
                 elseif px == intersectX then
                    return true
                 end
            end
        -- Handle point lying on a horizontal edge segment
        elseif py == p1.y and py == p2.y then
            if px >= math.min(p1.x, p2.x) and px <= math.max(p1.x, p2.x) then
                return true -- Point is on a horizontal edge
            end
        end
    end
    -- Odd number of crossings means the point is inside
    return crossings % 2 == 1
end

-- Function to transform local polygon vertices to world coordinates
-- Takes localVertices { {x=,y=}, ... }, object center (objX, objY), and object angle
-- Returns a new table of world coordinate vertices { {x=,y=}, ... }
function transformVertices(localVertices, objX, objY, objAngle)
    local worldVertices = {}
    local cosA = math.cos(objAngle)
    local sinA = math.sin(objAngle)
    for i, p in ipairs(localVertices) do
        local rotatedX = cosA * p.x - sinA * p.y
        local rotatedY = sinA * p.x + cosA * p.y
        table.insert(worldVertices, { x = objX + rotatedX, y = objY + rotatedY })
    end
    return worldVertices
end


-- Creates explosion particles at a given position
function createParticle(x, y, num)
    if x == nil or y == nil then return end -- Need a valid position
    for _ = 1, num do
        table.insert(particles, {
            x = x, y = y,
            dx = love.math.random() * PARTICLE_SPEED * 2 - PARTICLE_SPEED, -- Random direction/speed
            dy = love.math.random() * PARTICLE_SPEED * 2 - PARTICLE_SPEED,
            lifetime = PARTICLE_LIFETIME * (love.math.random() * 0.5 + 0.75) -- Slight variation
        })
    end
end

-- Smoothstep interpolation (for respawn animation)
function smoothstep(edge0, edge1, x)
    local t = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
end

-- Player Functions ----------------------------------------------------------

-- Resets player state (position, velocity, timers) - called on game start and respawn *finish*
function resetPlayerState()
    player.x = GAME_WIDTH / 2
    player.y = GAME_HEIGHT / 2
    player.dx = 0
    player.dy = 0
    player.angle = -math.pi / 2 -- Pointing up
    player.radius = 10 -- Collision radius (still useful for UFO/bullets)
    player.thrusting = false
    player.visible = false -- Start invisible by default (startGame or respawn anim will make visible)
    player.alive = false -- Start not alive by default
    player.isDying = false -- Not dying
    player.isRespawning = false -- Not respawning
    player.deathAnimProgress = 0
    player.respawnAnimProgress = 0
    player.deathX = nil -- Position at death (cleared)
    player.deathY = nil
    player.deathAngle = nil
    player.deathSegments = nil -- Clear segment data
    player.gameOverFadeTimer = nil -- Initialize game over fade timer
    player.shape = { -- Define ship shape relative to center (0,0)
        { x = 12, y = 0 }, -- Nose
        { x = -8, y = -7 }, -- Left wing back
        { x = -8, y = 7 } -- Right wing back
    }
    playerGunTimer = 0
    playerInvulnerableTimer = 0 -- Set by startGame or respawn finish
    playerHyperspaceTimer = 0
    print("Player State Reset (Positioned, invisible, not alive)")
end

-- Starts the respawn *animation* process (called immediately after death animation finishes)
function startRespawnAnimation()
    print("Starting Respawn Animation...")
    -- Set target position/angle for the *new* ship
    local respawnX = GAME_WIDTH / 2
    local respawnY = GAME_HEIGHT / 2
    player.x = respawnX
    player.y = respawnY
    player.dx = 0
    player.dy = 0
    player.angle = -math.pi / 2 -- Final angle should be pointing up
    player.visible = false -- Keep invisible until animation finishes
    player.alive = false -- Not truly 'alive' until animation finishes
    player.isRespawning = true -- Start the respawn animation flag
    player.respawnAnimProgress = 0 -- Start animation progress at 0

    -- Store the starting position/angle of each segment *relative to the new respawn point*
    -- This corrects for the coordinate system shift from death location to respawn location.
    if player.deathSegments then
        -- Ensure death coordinates are valid before proceeding
        if type(player.deathX) ~= "number" or type(player.deathY) ~= "number" then
            print("ERROR: Invalid death coordinates during startRespawnAnimation. Segments might jump.")
            -- As a fallback, just use the current segment offsets (will likely cause jump)
             for i, seg in ipairs(player.deathSegments) do
                seg.startX = seg.x
                seg.startY = seg.y
                seg.startAngle = seg.angle
             end
        else
            -- Calculate correct starting positions relative to the respawn point
            for i, seg in ipairs(player.deathSegments) do
                -- seg.x/y are offsets relative to player.deathX/Y
                local worldX = player.deathX + seg.x
                local worldY = player.deathY + seg.y
                -- Calculate the offset relative to the new respawn point
                seg.startX = worldX - respawnX
                seg.startY = worldY - respawnY
                -- Angle is absolute, so just store the current angle
                seg.startAngle = seg.angle
            end
        end
    else
         print("Warning: No death segments found during startRespawnAnimation.")
    end

    -- Play spawn sound *only* for respawn animation
    if sounds.player_spawn then sounds.player_spawn:play() end
end

-- Updates player logic (movement, shooting, timers)
function updatePlayer(dt)
    -- Don't update if not alive or during animations
    if not player or not player.alive or player.isDying or player.isRespawning then return end

    -- Update timers
    playerGunTimer = math.max(0, playerGunTimer - dt)
    playerInvulnerableTimer = math.max(0, playerInvulnerableTimer - dt)
    playerHyperspaceTimer = math.max(0, playerHyperspaceTimer - dt)

    -- Rotation
    if love.keyboard.isDown("left") then player.angle = player.angle - PLAYER_ROTATION_SPEED * dt end
    if love.keyboard.isDown("right") then player.angle = player.angle + PLAYER_ROTATION_SPEED * dt end

    -- Thrusting
    player.thrusting = false
    if love.keyboard.isDown("up") then
        player.thrusting = true
        -- Apply thrust in the direction the ship is facing
        player.dx = player.dx + math.cos(player.angle) * PLAYER_THRUST * dt
        player.dy = player.dy + math.sin(player.angle) * PLAYER_THRUST * dt
    end

    -- Manage thrust sound (STARTING the sound)
    if player.thrusting and not thrustPlaying then
        if sounds.thrust and not sounds.thrust:isPlaying() then sounds.thrust:play() end
        thrustPlaying = true
    -- Manage thrust sound (STOPPING the sound - only when alive and not thrusting)
    elseif not player.thrusting and thrustPlaying then
        if sounds.thrust then sounds.thrust:stop() end
        thrustPlaying = false
    end

    -- Apply friction
    player.dx = player.dx * PLAYER_FRICTION
    player.dy = player.dy * PLAYER_FRICTION
    -- Clamp speed to maximum
    local speedSq = player.dx^2 + player.dy^2
    if speedSq > PLAYER_MAX_SPEED^2 then
        local speed = math.sqrt(speedSq)
        player.dx = (player.dx / speed) * PLAYER_MAX_SPEED
        player.dy = (player.dy / speed) * PLAYER_MAX_SPEED
    end

    -- Update position and wrap around screen edges
    player.x = wrap(player.x + player.dx * dt, 0, GAME_WIDTH)
    player.y = wrap(player.y + player.dy * dt, 0, GAME_HEIGHT)

    -- Shooting
    if love.keyboard.isDown("space") and playerGunTimer <= 0 then
        fireBullet()
        playerGunTimer = PLAYER_GUN_COOLDOWN
    end

    -- Hyperspace
    if love.keyboard.isDown("h") and playerHyperspaceTimer <= 0 then
        player.x = love.math.random(GAME_WIDTH) -- Jump to random location
        player.y = love.math.random(GAME_HEIGHT)
        player.dx = 0; player.dy = 0 -- Stop movement
        playerHyperspaceTimer = PLAYER_HYPERSPACE_COOLDOWN
        playerInvulnerableTimer = 1.0 -- Brief invulnerability after jump
        if sounds.hyperspace then sounds.hyperspace:play() end
    end
end

-- Updates the death animation progress (segments flying apart)
-- Also handles game over fade timer
function updateDeathAnimation(dt)
    -- Allow updates if segments exist (for death anim and game over fade)
    if not player or not player.deathSegments then return end

    -- Update segment physics (position, angle, bounce)
    -- Update physics during dying AND game over (for fade)
    if player.isDying or gameState == "gameOver" then
        for i, seg in ipairs(player.deathSegments) do
            -- Update position (offset relative to player.deathX/Y)
            seg.x = seg.x + seg.vx * dt
            seg.y = seg.y + seg.vy * dt
            -- Update rotation
            seg.angle = seg.angle + seg.spin * dt

            -- Boundary collision check (bounce)
            local cosA = math.cos(seg.angle); local sinA = math.sin(seg.angle)
            local deathX = player.deathX or 0; local deathY = player.deathY or 0
            local worldX1 = deathX + seg.x + cosA * seg.p1.x - sinA * seg.p1.y
            local worldY1 = deathY + seg.y + sinA * seg.p1.x + cosA * seg.p1.y
            local worldX2 = deathX + seg.x + cosA * seg.p2.x - sinA * seg.p2.y
            local worldY2 = deathY + seg.y + sinA * seg.p2.x + cosA * seg.p2.y

            local bounced = false
            if (worldX1 < 0 and seg.vx < 0) or (worldX2 < 0 and seg.vx < 0) or (worldX1 > GAME_WIDTH and seg.vx > 0) or (worldX2 > GAME_WIDTH and seg.vx > 0) then
                seg.vx = -seg.vx * 0.8; seg.x = seg.x + seg.vx * dt; bounced = true
            end
            if (worldY1 < 0 and seg.vy < 0) or (worldY2 < 0 and seg.vy < 0) or (worldY1 > GAME_HEIGHT and seg.vy > 0) or (worldY2 > GAME_HEIGHT and seg.vy > 0) then
                seg.vy = -seg.vy * 0.8; seg.y = seg.y + seg.vy * dt; bounced = true
            end
            if bounced then
                seg.spin = seg.spin + (love.math.random() - 0.5) * 1.0
                seg.spin = math.max(-PLAYER_SEGMENT_MAX_SPIN, math.min(PLAYER_SEGMENT_MAX_SPIN, seg.spin))
            end
            seg.vx = seg.vx * 0.995; seg.vy = seg.vy * 0.995
        end
    end

    -- Update death animation progress only if dying
    if player.isDying then
        player.deathAnimProgress = math.min(1, player.deathAnimProgress + dt / PLAYER_DEATH_ANIM_DURATION)

        -- Check if death animation duration finished
        if player.deathAnimProgress >= 1 then
            player.isDying = false
            print("Death Animation Finished.")

            -- Check for game over or start respawn animation *immediately*
            -- Uses the already-decremented 'lives' count from playerHit
            if lives <= 0 then
                print("Game Over")
                gameState = "gameOver"; isGameOver = true
                player.gameOverFadeTimer = 0 -- Start the fade timer
                -- No specific game over sound call here
                if ufoActive and sounds.ufo_flying and sounds.ufo_flying:isPlaying() then sounds.ufo_flying:stop() end
                 -- Do not remove segments immediately, let them fade
            else
                print("Starting respawn animation immediately...")
                startRespawnAnimation() -- Trigger the respawn animation right away
            end
        end
    -- Update game over fade timer if game is over
    elseif gameState == "gameOver" and player.gameOverFadeTimer then
        player.gameOverFadeTimer = player.gameOverFadeTimer + dt
        -- Remove segments after fade is complete
        if player.gameOverFadeTimer > GAME_OVER_FADE_DURATION then
            print("Game over fade complete. Removing segments.")
            player.deathSegments = nil
            player.gameOverFadeTimer = nil -- Stop timer updates
        end
    end
end

-- Updates the respawn animation progress (segments flying back)
function updateRespawnAnimation(dt)
    if not player or not player.isRespawning or not player.deathSegments then return end

    player.respawnAnimProgress = math.min(1, player.respawnAnimProgress + dt / PLAYER_RESPAWN_ANIM_DURATION)
    local progress = smoothstep(0, 1, player.respawnAnimProgress) -- Use smoothed progress

    -- Update each segment, interpolating towards its final position/rotation relative to the respawn point
    for i, seg in ipairs(player.deathSegments) do
        -- Target position is (0, 0) relative to player's respawn center (player.x, player.y)
        local targetX = 0
        local targetY = 0
        -- Target angle is the player's final angle (absolute world angle)
        local targetAngle = player.angle -- Target the final upward orientation (-pi/2)

        -- Interpolate position (from seg.startX/Y recorded at start of respawn towards targetX/Y)
        -- seg.startX/Y are already relative to the respawn point (player.x, player.y)
        seg.x = seg.startX + (targetX - seg.startX) * progress
        seg.y = seg.startY + (targetY - seg.startY) * progress

        -- Interpolate angle (shortest path from seg.startAngle towards targetAngle)
        local angleDiff = targetAngle - seg.startAngle
        -- Wrap angle difference to the range [-pi, pi] for shortest rotation
        angleDiff = (angleDiff + math.pi) % (2 * math.pi) - math.pi
        seg.angle = seg.startAngle + angleDiff * progress
    end

    -- Check if animation finished
    if player.respawnAnimProgress >= 1 then
        print("Respawn Animation Finished.")
        player.isRespawning = false
        player.visible = true -- Make player visible (normal shape will be drawn now)
        player.alive = true -- Player is now controllable
        playerInvulnerableTimer = PLAYER_INVULNERABILITY_TIME -- Start invulnerability
        player.deathSegments = nil -- Clear segment data, no longer needed
        -- Player's final position and angle (player.x, player.y, player.angle) are already set correctly by startRespawnAnimation
    end
end


-- Internal function to draw the player ship shape or segments
function drawPlayer_Internal()
    if not player then return end

    -- Handle Invulnerability Blink (only when fully alive and not animating)
    if player.alive and not player.isDying and not player.isRespawning and playerInvulnerableTimer > 0 then
        -- Blink effect: skip drawing every few frames based on timer
        if math.floor(playerInvulnerableTimer * 10) % 2 == 0 then
            return -- Skip drawing this frame
        end
    end

    -- Determine the base position and if segments should be drawn
    local drawX, drawY
    -- Segments should be drawn if dying, respawning, OR game is over (and segments exist)
    local shouldDrawSegments = player.deathSegments and (player.isDying or player.isRespawning or gameState == "gameOver")

    if shouldDrawSegments then
        if player.isRespawning then
             drawX, drawY = player.x, player.y -- Use current player position as the center for respawn animation
        else -- Dying or Game Over
             -- Ensure death coordinates are valid
             if type(player.deathX) ~= "number" or type(player.deathY) ~= "number" then
                 print("Warning: Invalid death coordinates during drawPlayer_Internal (dying/gameOver). Using 0,0.")
                 drawX, drawY = 0, 0
             else
                 drawX, drawY = player.deathX, player.deathY -- Use the position where the player died
             end
        end
    elseif player.visible then -- Normal state (alive, not animating)
         drawX, drawY = player.x, player.y
    else
        return -- Don't draw if not visible and not animating segments
    end

    -- Check if position is valid before proceeding
    if type(drawX) ~= "number" or type(drawY) ~= "number" then
         print("Warning: Invalid player draw position", drawX, drawY)
         return -- Cannot draw if no valid position
    end

    love.graphics.push()
    love.graphics.translate(drawX, drawY) -- Move to the correct center point

    love.graphics.setColor(1, 1, 1, 1) -- White (default)

    -- Draw based on state
    if shouldDrawSegments then
        -- Draw segments (Dying, Respawning, or GameOver Fade)

        -- Calculate alpha based on game state (fade only on game over)
        local alpha = 1 -- Default to fully visible
        if gameState == "gameOver" and player.gameOverFadeTimer then
            -- Calculate fade out alpha based on timer
            local fadeDuration = GAME_OVER_FADE_DURATION or 1.5 -- Use constant or default
            alpha = math.max(0, 1 - (player.gameOverFadeTimer / fadeDuration))
        end

        love.graphics.setColor(1, 1, 1, alpha) -- Set color with calculated alpha

        -- No base rotation during respawn or game over fade drawing

        -- Draw each segment with its individual transform relative to the base
        for i, seg in ipairs(player.deathSegments) do
             -- Check if segment data is valid
             if seg and type(seg.x) == "number" and type(seg.y) == "number" and type(seg.angle) == "number" and seg.p1 and seg.p2 then
                love.graphics.push()
                -- Apply segment's individual transform (position and rotation) relative to the base transform
                love.graphics.translate(seg.x, seg.y)
                -- seg.angle represents the interpolated world angle during respawn, or the physics angle during death/fade
                love.graphics.rotate(seg.angle) -- Rotate segment itself
                love.graphics.line(seg.p1.x, seg.p1.y, seg.p2.x, seg.p2.y) -- Draw the segment line (using its local points)
                love.graphics.pop()
             else
                 print("Warning: Invalid segment data during drawing", i, seg)
             end
        end

    elseif player.visible then -- Normal drawing (alive and not animating)
        love.graphics.setColor(1, 1, 1, 1) -- Ensure fully visible
        -- Apply ship's current rotation (already translated)
        love.graphics.rotate(player.angle)
        -- Draw ship outline using the defined shape vertices
        local vertices = {}
        for _, p in ipairs(player.shape) do table.insert(vertices, p.x); table.insert(vertices, p.y) end
        if #vertices >= 6 then love.graphics.polygon("line", vertices) end

        -- Draw thrust flame if thrusting
        if player.thrusting then
            love.graphics.setColor(1, 0.7, 0.2, 1) -- Orange/Yellow
            local mainFlameLength = -13 - love.math.random(4) -- Base length + flicker
            love.graphics.line(-8, -4, mainFlameLength, 0, -8, 4) -- Draw main flame triangle
            -- Optional inner flame for more effect
            if love.math.random() > 0.5 then
               love.graphics.setColor(1, 1, 0.5, 0.8) -- Lighter yellow, slightly transparent
               local innerFlameLength = -10 - love.math.random(3)
               love.graphics.line(-8, -2, innerFlameLength, 0, -8, 2)
            end
        end
    end

    love.graphics.pop() -- Restore original transform
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

-- Called when the player is hit by an asteroid or UFO/bullet
function playerHit()
    -- Ignore hits if already dying, respawning, or invulnerable
    if not player or not player.alive or player.isDying or player.isRespawning or playerInvulnerableTimer > 0 then return end

    -- Decrement lives immediately on hit
    lives = lives - 1
    print("Player Hit! Lives left: " .. lives)

    -- Play standard explosion on EVERY death
    if sounds.player_explode then sounds.player_explode:play() end
    createParticle(player.x, player.y, 20) -- Visual explosion

    -- Stop thrust sound immediately on hit
    if thrustPlaying then
        if sounds.thrust then sounds.thrust:stop() end
        thrustPlaying = false
        print("Thrust sound stopped on hit.")
    end

    player.alive = false -- No longer controllable
    player.thrusting = false -- Stop thrusting visually
    player.isDying = true -- Start the death animation flag
    player.deathAnimProgress = 0 -- Start animation progress at 0
    player.visible = false -- Hide the main ship immediately

    -- Store death location and angle
    player.deathX = player.x
    player.deathY = player.y
    player.deathAngle = player.angle -- Store the angle at the moment of death

    -- Make UFO leave immediately when player is hit
    if ufoActive and ufo and not ufo.leaving then
        print("Player hit. Setting UFO to leave.")
        ufo.leaving = true
        if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then sounds.ufo_flying:stop() end
    end

    -- Create segment data based on the current player shape
    -- These exact segments will be animated flying apart and then back together.
    player.deathSegments = {}
    if player.shape and #player.shape >= 3 then
        for i = 1, #player.shape do
            local p1_idx = i
            local p2_idx = (i % #player.shape) + 1 -- Wrap around for the last segment

            -- Get the two endpoints of the segment relative to the ship's center (0,0)
            local p1_rel = { x = player.shape[p1_idx].x, y = player.shape[p1_idx].y }
            local p2_rel = { x = player.shape[p2_idx].x, y = player.shape[p2_idx].y }

            -- Calculate a random velocity and spin for the segment to fly off
            local angle = love.math.random() * 2 * math.pi
            local speed = love.math.random(PLAYER_SEGMENT_MAX_SPEED * 0.5, PLAYER_SEGMENT_MAX_SPEED)
            local vx = math.cos(angle) * speed
            local vy = math.sin(angle) * speed
            local spin = (love.math.random() - 0.5) * 2 * PLAYER_SEGMENT_MAX_SPIN

            table.insert(player.deathSegments, {
                p1 = p1_rel, -- Store original relative points of the segment
                p2 = p2_rel,
                x = 0, -- Initial offset from death point is 0
                y = 0,
                angle = player.deathAngle, -- Initial angle is player's angle at death
                vx = vx, -- Velocity for flying apart
                vy = vy,
                spin = spin, -- Rotation speed for flying apart
                -- startX/Y/Angle will be set just before respawn animation starts
                startX = 0, -- Placeholder, will be set to final death anim position relative to respawn point
                startY = 0, -- Placeholder
                startAngle = 0 -- Placeholder, will be set to final death anim angle
            })
        end
    else
        print("Warning: Player shape not defined correctly for death animation.")
    end
end

-- Bullet Functions ----------------------------------------------------------

-- Fires a bullet from the player's ship nose
function fireBullet()
    -- Check conditions for firing
    if not player or not player.alive or player.isDying or player.isRespawning or not player.shape or not player.shape[1] then return end
    if #bullets >= MAX_BULLETS then return end -- Limit bullets

    -- Calculate bullet starting position (tip of the ship)
    local cosA = math.cos(player.angle); local sinA = math.sin(player.angle)
    local noseX = player.shape[1].x; local noseY = player.shape[1].y
    -- Rotate the nose offset by the player's angle and add to player position
    local startX = player.x + cosA * noseX - sinA * noseY
    local startY = player.y + sinA * noseX + cosA * noseY

    -- Create the bullet object
    table.insert(bullets, {
        x = startX, y = startY,
        dx = cosA * BULLET_SPEED + (player.dx or 0), -- Add player's velocity
        dy = sinA * BULLET_SPEED + (player.dy or 0),
        lifetime = BULLET_LIFETIME, radius = 2
    })

    -- Play shooting sound (clone to allow overlapping sounds)
    if sounds.shoot then local s = sounds.shoot:clone(); if s then s:play() end end
end

-- Updates position and lifetime of player bullets
function updateBullets(dt)
    local i = #bullets
    while i >= 1 do
        local b = bullets[i]
        local removeBullet = false -- Flag to mark bullet for removal

        if not b then
            removeBullet = true -- Should not happen, but handle defensively
        else
            -- Update position with wrapping
            b.x = wrap(b.x + b.dx * dt, 0, GAME_WIDTH)
            b.y = wrap(b.y + b.dy * dt, 0, GAME_HEIGHT)

            -- Decrease lifetime
            b.lifetime = b.lifetime - dt

            -- Remove if lifetime expired
            if b.lifetime <= 0 then
                removeBullet = true
            end
        end

        -- Remove the bullet if flagged
        if removeBullet then
            table.remove(bullets, i)
        end
        i = i - 1 -- Move to the next bullet (iterating backwards)
    end
end

-- Internal function to draw a single bullet
function drawBullet_Internal(bullet)
    if not bullet or type(bullet.x) ~= "number" or type(bullet.y) ~= "number" then return end
    love.graphics.setColor(1, 1, 1, 1) -- White
    love.graphics.circle("fill", bullet.x, bullet.y, bullet.radius or 2)
end

-- Asteroid Functions --------------------------------------------------------

-- Creates a new asteroid, optionally at a specific position and size
function createAsteroid(x, y, size)
    size = size or 3 -- Default to large size (3)

    -- Spawn randomly outside safe zone if x,y not provided
    if not x or not y then
        local safeRadius = PLAYER_SPAWN_SAFE_ZONE_RADIUS or 150
        local checkX, checkY
        local dist = 0

        repeat
            -- Generate random position within screen bounds
            x = love.math.random(0, GAME_WIDTH)
            y = love.math.random(0, GAME_HEIGHT)

            -- Determine center point for safe zone check
            if player and (player.alive or player.isRespawning) and player.x and player.y then
                checkX, checkY = player.x, player.y -- Check against active player
            else
                checkX, checkY = GAME_WIDTH / 2, GAME_HEIGHT / 2 -- Check against screen center otherwise
            end

            -- Calculate distance
            dist = distance(x, y, checkX, checkY)

        until dist >= safeRadius -- Repeat until outside safe zone

        print(string.format("Spawned asteroid at %.1f, %.1f (Dist: %.1f)", x, y, dist))
    end

    -- Validate size and get properties
    if not ASTEROID_SIZE_MAP[size] then size = 3 end -- Fallback to large
    local radius = ASTEROID_SIZE_MAP[size]; local pointsValue = ASTEROID_POINTS[size]

    -- Calculate speed (smaller asteroids are faster)
    local speedMultiplier = 1.5 - (size * 0.3)
    local speed = love.math.random(ASTEROID_SPEED_MIN, ASTEROID_SPEED_MAX) * speedMultiplier
    local angle = love.math.random() * math.pi * 2 -- Random direction

    -- Create asteroid object
    local asteroid = {
        x = x, y = y, size = size, radius = radius,
        dx = math.cos(angle) * speed, dy = math.sin(angle) * speed,
        angle = 0, -- Rotation angle
        spin = (love.math.random() - 0.5) * 2, -- Random spin speed/direction
        points = pointsValue, shape = {}
    }

    -- Generate irregular shape vertices
    local numPoints = math.random(8, 12) -- Vary the number of points
    local baseRadius = asteroid.radius
    for i = 1, numPoints do
        local pointAngle = (i - 1) * (2 * math.pi / numPoints) -- Angle for this vertex
        -- Vary the distance from the center for irregularity
        local variation = love.math.random() * ASTEROID_IRREGULARITY * 2 + (1.0 - ASTEROID_IRREGULARITY)
        local r = baseRadius * variation
        asteroid.shape[i] = { x = math.cos(pointAngle) * r, y = math.sin(pointAngle) * r }
    end
    table.insert(asteroids, asteroid)
end

-- Spawns the initial set of asteroids for a wave
function spawnInitialAsteroids(num)
    asteroids = {} -- Clear existing asteroids
    for _ = 1, num do createAsteroid() end -- Call without coordinates to use random placement
end

-- Updates asteroid positions and rotation
function updateAsteroids(dt)
    -- Iterate backwards for safe removal (though not removing here)
    for i = #asteroids, 1, -1 do
        local a = asteroids[i]
        if a then
            -- Update position with wrapping
            a.x = wrap(a.x + a.dx * dt, 0, GAME_WIDTH)
            a.y = wrap(a.y + a.dy * dt, 0, GAME_HEIGHT)
            -- Update rotation
            a.angle = a.angle + a.spin * dt
        else table.remove(asteroids, i) -- Remove if nil (error case)
        end
    end
end

-- Internal function to draw a single asteroid
function drawAsteroid_Internal(asteroid)
    -- Basic validation
    if not asteroid or not asteroid.shape or #asteroid.shape < 3 then return end
    if type(asteroid.x) ~= "number" or type(asteroid.y) ~= "number" then return end

    love.graphics.push()
    love.graphics.translate(asteroid.x, asteroid.y)
    love.graphics.rotate(asteroid.angle)
    love.graphics.setColor(1, 1, 1, 1) -- White

    -- Collect vertices for drawing
    local vertices = {}
    for j, point in ipairs(asteroid.shape) do table.insert(vertices, point.x); table.insert(vertices, point.y) end
    love.graphics.polygon("line", vertices) -- Draw outline

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

-- Handles asteroid destruction (hit by bullet)
function breakAsteroid(index)
    if index < 1 or index > #asteroids or not asteroids[index] then return end -- Ensure asteroid exists and index is valid
    local oldAsteroid = asteroids[index]
    score = score + (oldAsteroid.points or 0) -- Add score

    -- Play explosion sound and create particles
    if sounds.explosion then local s = sounds.explosion:clone(); if s then s:play() end end
    createParticle(oldAsteroid.x, oldAsteroid.y, 10)

    -- Spawn smaller asteroids if it wasn't a small one
    if oldAsteroid.size > 1 then
        local newSize = oldAsteroid.size - 1
        -- Create two smaller ones near the original position
        createAsteroid(oldAsteroid.x + love.math.random(-5, 5), oldAsteroid.y + love.math.random(-5, 5), newSize)
        createAsteroid(oldAsteroid.x + love.math.random(-5, 5), oldAsteroid.y + love.math.random(-5, 5), newSize)
    end
    table.remove(asteroids, index) -- Remove the destroyed asteroid

    -- Check if wave is cleared (only if player is alive and no UFO)
    if gameState == "playing" and #asteroids == 0 and not ufoActive and player and player.alive and not player.isDying and not player.isRespawning then
        wave = wave + 1
        print("Wave Cleared! Starting Wave " .. wave)
        spawnInitialAsteroids(wave + 3) -- Spawn more asteroids for next wave
    end
end

-- UFO Functions -------------------------------------------------------------

-- Spawns the UFO if not already active
function spawnUFO()
    if ufoActive then return end -- Only one UFO at a time
    local side = love.math.random(2); local x, y, dx, dy; local buffer = 20 -- Spawn margin

    -- Choose vertical position and starting side/direction
    y = love.math.random(GAME_HEIGHT * 0.2, GAME_HEIGHT * 0.8) -- Avoid top/bottom edges
    if side == 1 then x, dx, dy = -buffer, UFO_SPEED, 0 -- Left side, moving right
    else x, dx, dy = GAME_WIDTH + buffer, -UFO_SPEED, 0 end -- Right side, moving left

    -- Create UFO object
    ufo = {
        x = x, y = y, dx = dx, dy = dy, radius = 15, -- Keep radius for collision with player/UFO bullets
        -- Shape vertices for drawing
        shape = { -15, 0, -10, -5, 10, -5, 15, 0, 10, 5, -10, 5, -15, 0, -- Main body
                  -10, -5, -5, -10, 5, -10, 10, -5, -- Top saucer part lines
                  5, -10, 0, -13, -5, -10 }, -- Antenna thingy
        visible = true,
        leaving = false, -- Flag to indicate if UFO is flying off-screen
        lifetime = love.math.random(UFO_MIN_LIFETIME, UFO_MAX_LIFETIME) -- *** ADDED: Set random lifetime ***
    }
    ufoActive = true
    ufoFireTimer = UFO_FIRE_RATE / 2 -- Start with shorter delay for first shot
    ufoDirectionChangeTimer = UFO_DIRECTION_CHANGE_INTERVAL * love.math.random(0.5, 1.0) -- Random initial change timer

    -- Play spawn and flying sounds
    if sounds.ufo_spawn then sounds.ufo_spawn:play() end
    if sounds.ufo_flying then sounds.ufo_flying:setLooping(true); sounds.ufo_flying:play() end
    print("UFO Spawned with lifetime: " .. ufo.lifetime)
end

-- Updates UFO movement, shooting, and state
function updateUFO(dt)
    if not ufoActive or not ufo then return end

    local despawn_buffer = 30 -- Extra margin before despawning off-screen

    -- Handle leaving state (moves straight off-screen quickly)
    if ufo.leaving then
        local direction = (ufo.dx > 0 and 1 or -1) -- Maintain original horizontal direction
        -- Ensure dx is set if it somehow became 0 while leaving
        if ufo.dx == 0 then ufo.dx = (ufo.x > GAME_WIDTH / 2) and -UFO_SPEED or UFO_SPEED end
        ufo.dx = (ufo.dx > 0 and 1 or -1) * UFO_SPEED * UFO_LEAVING_SPEED_MULTIPLIER -- Increased speed
        ufo.dy = 0 -- No vertical movement when leaving
        ufo.x = ufo.x + ufo.dx * dt
        -- No vertical wrapping during exit

        -- Check if off-screen
        if (ufo.dx > 0 and ufo.x > GAME_WIDTH + despawn_buffer) or (ufo.dx < 0 and ufo.x < -despawn_buffer) then
            destroyUFO(false) -- Despawn without score
        end
        return -- Skip normal update logic if leaving
    end

    -- *** ADDED: Update lifetime and check if time to leave ***
    if not ufo.leaving then
        ufo.lifetime = ufo.lifetime - dt
        if ufo.lifetime <= 0 then
            print("UFO lifetime expired. Setting to leave.")
            ufo.leaving = true
            if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then sounds.ufo_flying:stop() end
            -- Let the leaving block handle movement/despawn in the next frame
            return -- Exit update for this frame
        end
    end
    -- *** END ADDED ***

    -- Normal movement
    ufo.x = ufo.x + ufo.dx * dt
    ufo.y = ufo.y + ufo.dy * dt

    -- Random direction changes
    ufoDirectionChangeTimer = ufoDirectionChangeTimer - dt
    if ufoDirectionChangeTimer <= 0 then
        local changeType = love.math.random(3) -- Type of change

        if changeType == 1 then -- Change vertical direction randomly
            ufo.dy = (love.math.random(3) - 2) * UFO_SPEED * love.math.random(0.4, 0.9) -- Up, down, or straight
        elseif changeType == 2 and ufo.dy ~= 0 then -- Change horizontal direction randomly (only if moving vertically)
             ufo.dx = (love.math.random(3) - 2) * UFO_SPEED * love.math.random(0.4, 0.9) -- Left, right, or straight (less likely)
        elseif changeType == 3 and player and player.alive and not player.isDying and not player.isRespawning then -- Target player's general Y area (only if player is alive)
            local targetY = player.y + love.math.random(-GAME_HEIGHT * 0.25, GAME_HEIGHT * 0.25) -- Aim near player Y
            ufo.dy = (targetY > ufo.y and 1 or -1) * UFO_SPEED * love.math.random(0.3, 0.7) -- Move towards target Y
        end

        -- Ensure it always has some horizontal movement if change resulted in none
        if ufo.dx == 0 then
             ufo.dx = (ufo.x < GAME_WIDTH / 2) and UFO_SPEED * 0.5 or -UFO_SPEED * 0.5 -- Move slowly towards center if stopped
        end

        -- Ensure horizontal speed is reset to base UFO speed (unless changed)
        if ufo.dx ~= 0 then
             ufo.dx = (ufo.dx > 0) and UFO_SPEED or -UFO_SPEED
        end

        ufoDirectionChangeTimer = UFO_DIRECTION_CHANGE_INTERVAL * love.math.random(0.4, 1.0) -- Reset timer
    end

    -- Shooting (only if player is alive)
    ufoFireTimer = ufoFireTimer - dt
    if ufoFireTimer <= 0 and player and player.alive and not player.isDying and not player.isRespawning then
        fireUFOBullet()
        ufoFireTimer = UFO_FIRE_RATE * love.math.random(0.8, 1.2) -- Randomize next shot time slightly
    end

    -- *** CHANGE: Conditional Vertical Wrapping ***
    -- Only wrap vertically if UFO is fully on screen horizontally and not leaving
    local onScreenBuffer = 5 -- Small buffer to ensure it's fully visible before wrapping
    if not ufo.leaving and ufo.x > onScreenBuffer and ufo.x < GAME_WIDTH - onScreenBuffer then
        ufo.y = wrap(ufo.y, 0, GAME_HEIGHT)
    -- else: Do not wrap if entering, leaving, or exactly on edge
    end
    -- *** END CHANGE ***

    -- Trigger leaving state if UFO reaches edge naturally (backup to lifetime)
    if not ufo.leaving then
         if (ufo.dx > 0 and ufo.x >= GAME_WIDTH) or (ufo.dx < 0 and ufo.x <= 0) then
            print("UFO reached edge naturally. Setting to leave.")
            ufo.leaving = true
            if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then sounds.ufo_flying:stop() end
            -- The 'if ufo.leaving then' block at the top will handle the rest
         end
    end

    -- Update UFO bullets
    for i = #ufoBullets, 1, -1 do
        local b = ufoBullets[i]
        if b then
            b.x = wrap(b.x + b.dx * dt, 0, GAME_WIDTH)
            b.y = wrap(b.y + b.dy * dt, 0, GAME_HEIGHT)
            b.lifetime = b.lifetime - dt
            if b.lifetime <= 0 then table.remove(ufoBullets, i) end
        else table.remove(ufoBullets, i) -- Remove if nil
        end
    end
end

-- Internal function to draw the UFO shape and its bullets
function drawUFO_Internal()
    if not ufoActive or not ufo then return end
    if type(ufo.x) ~= "number" or type(ufo.y) ~= "number" or not ufo.shape then return end

    -- Draw UFO body
    love.graphics.setColor(1, 1, 1, 1) -- White
    love.graphics.push()
    love.graphics.translate(ufo.x, ufo.y)
    if #ufo.shape >= 6 then love.graphics.polygon("line", ufo.shape) end
    love.graphics.pop()

    -- Draw UFO bullets (only if not leaving)
    if not ufo.leaving then
        love.graphics.setColor(1, 0, 0, 1) -- Red bullets
        for _, b in ipairs(ufoBullets) do drawBullet_Internal(b) end
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
    end
end

-- Fires a bullet from the UFO
function fireUFOBullet()
    -- Check conditions (player must be alive and not animating)
    if not ufo or not player or not player.alive or player.isDying or player.isRespawning or ufo.leaving then return end

    -- Aim slightly inaccurately towards the player
    local angleToPlayer = math.atan2(player.y - ufo.y, player.x - ufo.x)
    angleToPlayer = angleToPlayer + (love.math.random() - 0.5) * 0.3 -- Add random offset (radians)

    -- Create bullet
    table.insert(ufoBullets, {
        x = ufo.x, y = ufo.y,
        dx = math.cos(angleToPlayer) * UFO_BULLET_SPEED,
        dy = math.sin(angleToPlayer) * UFO_BULLET_SPEED,
        lifetime = 2.0, radius = 3 -- Slightly larger radius than player bullets
    })

    -- Play sound
    if sounds.ufo_shoot then local s = sounds.ufo_shoot:clone(); if s then s:play() end end
end

-- Removes the UFO from the game
function destroyUFO(hitByPlayer)
    if not ufoActive then return end -- Already gone

    if hitByPlayer then
        score = score + UFO_POINTS -- Award points
        if sounds.explosion then local s = sounds.explosion:clone(); if s then s:play() end end
        if ufo then createParticle(ufo.x, ufo.y, 15) end -- Visual effect
    end

    -- Stop flying sound
    if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then sounds.ufo_flying:stop() end

    -- Reset UFO state
    print("Destroying UFO. Active: false")
    ufo = nil; ufoActive = false; ufoBullets = {}; timeSinceLastUFO = 0

    -- Check for wave clear after UFO is destroyed (if player is alive)
    if gameState == "playing" and #asteroids == 0 and not ufoActive and player and player.alive and not player.isDying and not player.isRespawning then
        wave = wave + 1
        print("Wave Cleared (after UFO)! Starting Wave " .. wave)
        spawnInitialAsteroids(wave + 3)
    end
end

-- Particle Functions --------------------------------------------------------

-- Updates particle positions and lifetimes
function updateParticles(dt)
    -- Iterate backwards for safe removal
    for i = #particles, 1, -1 do
        local p = particles[i]
        if p then
            -- Update position (no wrapping for particles)
            p.x = p.x + p.dx * dt; p.y = p.y + p.dy * dt
            -- Decrease lifetime
            p.lifetime = p.lifetime - dt
            -- Remove if expired
            if p.lifetime <= 0 then table.remove(particles, i) end
        else table.remove(particles, i) -- Remove if nil
        end
    end
end

-- Internal function to draw all active particles
function drawParticles_Internal()
    love.graphics.setColor(1, 1, 1, 1) -- Default white
    for _, p in ipairs(particles) do
        if p and type(p.x) == "number" and type(p.y) == "number" then
            -- Fade out based on remaining lifetime
            local alpha = math.max(0, p.lifetime / PARTICLE_LIFETIME)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.points(p.x, p.y) -- Draw as single points
        end
    end
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

-- Game Flow Functions -------------------------------------------------------

-- Initializes the game state for a new game
function startGame()
    print("Starting New Game...")
    -- Reset scores, lives, wave
    score = 0; lives = 3; wave = 0
    -- Clear game objects
    asteroids = {}; bullets = {}; ufoBullets = {}; particles = {}
    destroyUFO(false) -- Ensure no UFO active

    resetPlayerState() -- Reset player fully (starts invisible, not alive)

    -- Make player instantly visible and alive for the *first* spawn
    player.visible = true
    player.alive = true
    playerInvulnerableTimer = PLAYER_INVULNERABILITY_TIME -- Grant initial invulnerability
    -- DO NOT play spawn sound here (only play on respawn animation)

    -- Set game state
    gameState = "playing"; isGameOver = false; timeSinceLastUFO = 0
    -- Start first wave
    wave = 1
    spawnInitialAsteroids(wave + 2) -- Initial asteroids

    -- Ensure thrust sound is stopped
    if thrustPlaying then if sounds.thrust then sounds.thrust:stop() end; thrustPlaying = false end
    print("First spawn complete (instant).")
end

-- Checks for all relevant collisions in the game
function checkCollisions()
    local playerWasHit = false -- Flag to stop further checks if player gets hit

    -- Player vs Asteroids (Polygon check)
    -- *** NOTE: Invulnerability check only prevents playerHit() from being called ***
    if player and player.alive and not player.isDying and not player.isRespawning then
        local playerWorldPoly = transformVertices(player.shape, player.x, player.y, player.angle)
        for i = #asteroids, 1, -1 do
            local a = asteroids[i]
            if a and a.shape then
                local asteroidWorldPoly = transformVertices(a.shape, a.x, a.y, a.angle)
                local collisionDetected = false
                if playerWorldPoly then
                    for _, pVertex in ipairs(playerWorldPoly) do
                        if pointInPolygon(asteroidWorldPoly, pVertex.x, pVertex.y) then collisionDetected = true; break end
                    end
                end
                if not collisionDetected and playerWorldPoly then
                    for _, aVertex in ipairs(asteroidWorldPoly) do
                        if pointInPolygon(playerWorldPoly, aVertex.x, aVertex.y) then collisionDetected = true; break end
                    end
                end
                if collisionDetected and playerInvulnerableTimer <= 0 then -- Only call playerHit if not invulnerable
                    playerHit()
                    playerWasHit = true
                    break
                end
            end
        end
    end
    if playerWasHit then return end

    -- Player vs UFO Body (Circle check)
    -- *** NOTE: Invulnerability check only prevents playerHit() from being called ***
    if player and player.alive and not player.isDying and not player.isRespawning and ufoActive and ufo and not ufo.leaving then
        if checkCircleCollision(player, ufo) and playerInvulnerableTimer <= 0 then -- Only call playerHit if not invulnerable
            playerHit()
            playerWasHit = true
        end
    end
    if playerWasHit then return end

     -- Player vs UFO Bullets (Circle check)
     -- *** NOTE: Invulnerability check only prevents playerHit() from being called ***
    if player and player.alive and not player.isDying and not player.isRespawning and ufoActive and ufo and not ufo.leaving then
        local ufoBulletIndex = #ufoBullets
        while ufoBulletIndex >= 1 do
            local ub = ufoBullets[ufoBulletIndex]
            if ub and checkCircleCollision(player, ub) then
                 table.remove(ufoBullets, ufoBulletIndex) -- Remove the bullet regardless
                 if playerInvulnerableTimer <= 0 then -- Only call playerHit if not invulnerable
                    playerHit()
                    playerWasHit = true
                    break -- Stop checking UFO bullets this frame if hit
                 end
            end
            ufoBulletIndex = ufoBulletIndex - 1
        end
    end
    if playerWasHit then return end

    -- Player Bullets vs Asteroids (Polygon check)
    -- *** NOTE: No invulnerability check here - bullets always work ***
    local bulletIndex = #bullets
    while bulletIndex >= 1 do
        local b = bullets[bulletIndex]
        local bulletRemoved = false

        if not b then
            table.remove(bullets, bulletIndex); bulletRemoved = true
        else
            local asteroidIndex = #asteroids
            while asteroidIndex >= 1 do
                local a = asteroids[asteroidIndex]
                if a and a.shape then
                    local worldPoly = transformVertices(a.shape, a.x, a.y, a.angle)
                    if pointInPolygon(worldPoly, b.x, b.y) then
                        table.remove(bullets, bulletIndex)
                        bulletRemoved = true
                        breakAsteroid(asteroidIndex)
                        break
                    end
                end
                asteroidIndex = asteroidIndex - 1
            end
        end
        if not bulletRemoved then bulletIndex = bulletIndex - 1
        else bulletIndex = #bullets end
    end

    -- Player Bullets vs UFO (Circle check)
    -- *** NOTE: No invulnerability check here - bullets always work ***
    if ufoActive and ufo and not ufo.leaving then
        local bulletIndexUFO = #bullets
        while bulletIndexUFO >= 1 do
            local b = bullets[bulletIndexUFO]
            if b and checkCircleCollision(b, ufo) then
                table.remove(bullets, bulletIndexUFO)
                destroyUFO(true)
                break
            end
            bulletIndexUFO = bulletIndexUFO - 1
        end
    end
end

-- Asset Loading -------------------------------------------------------------

-- Loads fonts, with fallbacks
function loadFonts()
    local success
    print("Loading fonts...")
    -- Try loading the custom font
    success, defaultFont = pcall(love.graphics.newFont, FONT_PATH, 18)
    if not success then
       print("Warning: Could not load '"..FONT_PATH.."'. Trying default LÖVE font.")
       -- Try loading the default built-in font
       success, defaultFont = pcall(love.graphics.newFont, 18)
       if not success then
           print("ERROR: Failed to load any default font (18pt). Text will not render.")
           -- Create a dummy font object to avoid errors later
           local dummyFont = { setFilter = function() end, getHeight = function() return 10 end, getWidth = function() return 10 end }
           defaultFont = dummyFont; titleFont = dummyFont; promptFont = dummyFont; gameOverFont = dummyFont
           return -- Stop trying to load other sizes
       end
    end
    print("Default font loaded successfully.")

    -- Load other font sizes, falling back to defaultFont if custom fails
    success, titleFont = pcall(love.graphics.newFont, FONT_PATH, 40)
    if not success then titleFont = defaultFont; print("Warning: Using default font size for title.") end

    success, promptFont = pcall(love.graphics.newFont, FONT_PATH, 20)
    if not success then promptFont = defaultFont; print("Warning: Using default font size for prompts.") end

    gameOverFont = titleFont -- Use the same large font for game over

    -- Set nearest neighbor filtering for pixelated look (optional)
    if defaultFont and defaultFont.setFilter then defaultFont:setFilter("nearest", "nearest") end
    if titleFont and titleFont.setFilter then titleFont:setFilter("nearest", "nearest") end
    if promptFont and promptFont.setFilter then promptFont:setFilter("nearest", "nearest") end

    print("Font loading and setup complete.")
end

-- Generates simple sound effects programmatically using SoundData
function loadSounds()
    print("Generating sounds using SoundData...")
    local sampleRate = 22050; local bitDepth = 16; local channels = 1
    local success, result

    -- Dummy sound object to prevent errors if generation fails
    local dummySound = { play = function() end, stop = function() end, isPlaying = function() return false end, setLooping = function() end, setVolume = function() end, clone = function() return dummySound end }

    -- Helper to create a Source from SoundData, with error handling
    local function createSource(data, type)
        local suc, src = pcall(love.audio.newSource, data, type); if suc then return src else print("ERROR creating source:", src); return dummySound end
    end

    -- Thrust (Low rumble with LFO)
    local thrustDurationSamples = sampleRate * 2 -- 2 seconds loop
    success, result = pcall(love.sound.newSoundData, thrustDurationSamples, sampleRate, bitDepth, channels)
    if success then
        local thrustData = result; local base_volume = 0.15; local lfo_freq = 0.7; local lfo_depth = 0.2
        for i = 0, thrustData:getSampleCount() - 1 do
            local lfo_phase = (i / sampleRate) * lfo_freq * 2 * math.pi -- Low frequency oscillator phase
            local volume_mod = (1.0 - lfo_depth) + lfo_depth * (math.sin(lfo_phase) * 0.5 + 0.5) -- Modulate volume
            local sampleValue = (love.math.random() * 2 - 1) * base_volume * volume_mod -- White noise modulated
            thrustData:setSample(i, sampleValue)
        end; sounds.thrust = createSource(thrustData, "static"); sounds.thrust:setLooping(true)
    else print("ERROR creating thrust SoundData:", result); sounds.thrust = dummySound end

    -- Player Shoot (Downward pitch sweep)
    success, result = pcall(love.sound.newSoundData, 4096, sampleRate, bitDepth, channels) -- Short duration
    if success then
        local fireData = result
        for i = 0, fireData:getSampleCount() - 1 do
            local t = i / fireData:getSampleCount() -- Normalized time (0 to 1)
            local freq = 1200 - 800 * t -- Frequency decreases over time
            fireData:setSample(i, math.sin(t * freq * math.pi * 2) * 0.4 * (1 - t*0.8)) -- Sine wave with decay
        end; sounds.shoot = createSource(fireData, "static")
    else print("ERROR creating shoot SoundData:", result); sounds.shoot = dummySound end

    -- Explosion (White noise burst with decay)
    success, result = pcall(love.sound.newSoundData, 8192, sampleRate, bitDepth, channels) -- Medium duration
    if success then
        local explosionData = result
        for i = 0, explosionData:getSampleCount() - 1 do
            local t = i / explosionData:getSampleCount()
            explosionData:setSample(i, (love.math.random() * 2 - 1) * (1 - t) * 0.5) -- Noise fades out
        end; sounds.explosion = createSource(explosionData, "static")
    else print("ERROR creating explosion SoundData:", result); sounds.explosion = dummySound end

    -- Player Explode (Multiple decaying noise bursts)
    local deathDurationSamples = 22050 -- 1 second
    success, result = pcall(love.sound.newSoundData, deathDurationSamples, sampleRate, bitDepth, channels)
    if success then
        local deathData = result; local numBooms = 4; local silenceFraction = 0.01
        local totalCycleSamples = math.floor(deathDurationSamples / numBooms)
        local boomSamples = math.floor(totalCycleSamples * (1 - silenceFraction)); local initialVolume = 0.75
        for i = 0, deathData:getSampleCount() - 1 do
            local currentCycleIndex = math.min(math.floor(i / totalCycleSamples), numBooms - 1)
            local sampleInCycle = i % totalCycleSamples; local sampleValue = 0
            if sampleInCycle < boomSamples then -- Only generate noise during the 'boom' part
                local volumeMultiplier = ((numBooms - currentCycleIndex) / numBooms)^2 -- Each boom quieter
                local currentVolume = initialVolume * math.max(0, volumeMultiplier)
                sampleValue = (love.math.random() * 2 - 1) * currentVolume
            end; deathData:setSample(i, sampleValue)
        end; sounds.player_explode = createSource(deathData, "static")
    else print("ERROR creating player_explode SoundData:", result); sounds.player_explode = dummySound end

    -- Player Spawn (Clicks) -- Removed Hum
    local playerSpawnSampleCount = math.floor(sampleRate * 0.7) -- ~0.7 seconds total
    success, result = pcall(love.sound.newSoundData, playerSpawnSampleCount, sampleRate, bitDepth, channels)
    if success then
        local spawnData = result
        local numClicks = 3
        local clickDuration = 0.05 -- seconds per click
        local clickInterval = 0.08 -- seconds between start of clicks

        -- Generate clicks
        for c = 1, numClicks do
            local clickStartSample = math.floor((c - 1) * clickInterval * sampleRate)
            local clickEndSample = math.min(clickStartSample + clickDuration * sampleRate, playerSpawnSampleCount - 1)
            for i = clickStartSample, clickEndSample do
                local t = (i - clickStartSample) / (clickEndSample - clickStartSample + 1)
                local clickAmp = 0.3 * (1 - t) -- Decay
                spawnData:setSample(i, (love.math.random() * 2 - 1) * clickAmp) -- White noise click
            end
        end

        sounds.player_spawn = createSource(spawnData, "static")
        print("Player Spawn sound generated (Clicks only).")
    else print("ERROR creating player_spawn SoundData:", result); sounds.player_spawn = dummySound end


    -- UFO Spawn (Short high beep)
    success, result = pcall(love.sound.newSoundData, 4410, sampleRate, bitDepth, channels) -- Very short
    if success then
        local spawnData = result
        for i = 0, spawnData:getSampleCount() - 1 do
            local t = i / spawnData:getSampleCount()
            spawnData:setSample(i, math.sin(t * 900 * math.pi * 2) * 0.3 * (1-t)) -- Simple sine wave fade out
        end; sounds.ufo_spawn = createSource(spawnData, "static")
    else print("ERROR creating ufo_spawn SoundData:", result); sounds.ufo_spawn = dummySound end

    -- UFO Flying (Siren sound)
    success, result = pcall(love.sound.newSoundData, sampleRate, sampleRate, bitDepth, channels) -- 1 second loop
    if success then
        local flyingData = result
        local baseFreq = 800 -- Center frequency
        local lfoFreq = 1.5 -- Slower oscillation frequency (Hz)
        local lfoDepth = 300 -- How much the pitch changes (Hz)
        local amplitude = 0.25 -- Volume

        for i = 0, flyingData:getSampleCount() - 1 do
            local time = i / sampleRate -- Current time in seconds within the loop
            local lfoVal = math.sin(time * lfoFreq * math.pi * 2) -- LFO value (-1 to 1)
            local currentFreq = baseFreq + lfoVal * lfoDepth -- Modulated frequency
            -- Use 'time' for the main sine wave phase calculation as well
            flyingData:setSample(i, math.sin(time * currentFreq * math.pi * 2) * amplitude)
        end
        sounds.ufo_flying = createSource(flyingData, "static"); sounds.ufo_flying:setLooping(true)
        print("UFO Flying sound generated (Siren).")
    else print("ERROR creating ufo_flying SoundData:", result); sounds.ufo_flying = dummySound end

    -- UFO Shoot (Similar to player shoot, maybe higher pitch?)
    success, result = pcall(love.sound.newSoundData, 4096, sampleRate, bitDepth, channels)
    if success then
        local ufoShootData = result
        for i = 0, ufoShootData:getSampleCount() - 1 do
            local t = i / ufoShootData:getSampleCount(); local freq = 1400 - 700 * t -- Higher start pitch?
            ufoShootData:setSample(i, math.sin(t * freq * math.pi * 2) * 0.4 * (1 - t*0.8))
        end; sounds.ufo_shoot = createSource(ufoShootData, "static")
    else print("ERROR creating ufo_shoot SoundData:", result); sounds.ufo_shoot = dummySound end

    -- Hyperspace (Weird rising/falling pitch)
    success, result = pcall(love.sound.newSoundData, 8820, sampleRate, bitDepth, channels)
    if success then
        local hyperData = result
        for i = 0, hyperData:getSampleCount() - 1 do
            local t = i / hyperData:getSampleCount(); local freq = 400 + 1200 * math.sin(t * math.pi) -- Pitch rises then falls
            hyperData:setSample(i, math.sin(t * freq * math.pi * 2) * 0.3 * (1-t))
        end; sounds.hyperspace = createSource(hyperData, "static")
    else print("ERROR creating hyperspace SoundData:", result); sounds.hyperspace = dummySound end

    -- Game Over (Long decaying low tone) - Kept generation code, but sound is not played
    success, result = pcall(love.sound.newSoundData, 65536, sampleRate, bitDepth, channels) -- Long duration
    if success then
        local gameOverData = result
        for i = 0, gameOverData:getSampleCount() - 1 do
            local t = i / gameOverData:getSampleCount()
            local freq = 220 * (1 - t * 0.98) -- Very slow pitch decay
            local amplitude = 0.8 * (1 - t * 0.8) -- Slow fade out (Kept increased volume)
            gameOverData:setSample(i, math.sin(t * freq * math.pi * 2) * amplitude)
        end
        sounds.gameOver = createSource(gameOverData, "static")
    else print("ERROR creating gameOver SoundData:", result); sounds.gameOver = dummySound end

    print("Sound generation complete.")
end

-- LÖVE Callback Functions ---------------------------------------------------

-- Called once at the start of the game
function love.load()
    -- Set master volume
    if love.audio then love.audio.setVolume(0.5); print("Master volume set to: " .. love.audio.getVolume())
    else print("Warning: love.audio module not available.") end

    -- Graphics settings
    love.graphics.setBackgroundColor(0, 0, 0) -- Black background
    love.graphics.setLineWidth(1.5) -- Default line thickness

    -- Seed random number generator
    love.math.setRandomSeed(os.time())

    -- Load assets
    loadSounds()
    loadFonts()
    if defaultFont then love.graphics.setFont(defaultFont) end -- Set default font

    -- Initialize game state
    gameState = "title"
    resetPlayerState() -- Initialize player table structure (invisible, not alive)
    player.visible = false -- Keep player hidden on title screen
    player.alive = false
    print("Game loaded. State: " .. gameState)
end

-- Called repeatedly, handles game logic updates
function love.update(dt)
    dt = math.min(dt, 1/30) -- Clamp delta time to avoid large physics steps

    if gameState == "playing" then
        -- Handle Death Animation (Segments flying)
        -- This now triggers startRespawnAnimation immediately upon completion if lives > 0
        -- OR handles game over state transition and starts fade timer
        updateDeathAnimation(dt)

        -- Handle Respawn Animation (Segments returning)
        updateRespawnAnimation(dt)

        -- Update controllable player state ONLY if fully alive (not dying, not respawning)
        if player and player.alive and not player.isDying and not player.isRespawning then
             updatePlayer(dt) -- Update player movement/actions
        end

        -- Update other game objects regardless of player animation state
        updateAsteroids(dt)
        updateBullets(dt)
        updateUFO(dt)
        updateParticles(dt)

        -- Check collisions (only if player is alive and vulnerable)
        -- Note: checkCollisions itself handles the invulnerability check for player hits
        if player and player.alive and not player.isDying and not player.isRespawning then
            checkCollisions()
        end

        -- Spawn UFO logic (only if player is alive and not currently animating)
        if not ufoActive and player and player.alive and not player.isDying and not player.isRespawning then
            timeSinceLastUFO = timeSinceLastUFO + dt
            if timeSinceLastUFO > ufoSpawnInterval then
                spawnUFO()
            end
        end

    elseif gameState == "gameOver" then
        -- Keep updating particles and UFO (so it flies off)
        -- Also keep updating death segments for fade-out effect
        updateDeathAnimation(dt) -- Continues segment physics and updates fade timer
        updateParticles(dt)
        updateUFO(dt) -- Allow UFO to continue its movement (likely 'leaving')

        -- Ensure thrust sound is stopped
        if thrustPlaying then if sounds.thrust then sounds.thrust:stop() end; thrustPlaying = false end

    elseif gameState == "title" then
        -- Nothing to update on the title screen currently
    end
end

-- Draws the game UI elements (score, lives, messages)
function drawUI()
    love.graphics.setColor(1, 1, 1, 1) -- White text
    local currentFont = love.graphics.getFont() -- Remember current font

    -- Score and Lives (only during play and game over)
    if (gameState == "playing" or gameState == "gameOver") and defaultFont then
        love.graphics.setFont(defaultFont)
        -- Draw Score (top right)
        love.graphics.printf("SCORE " .. score, 10, 10, GAME_WIDTH - 20, "right")
        -- Draw Lives (top left)
        -- Determine how many life icons to draw
        local livesToDraw = 0
        if lives > 0 then
            -- If player is fully alive, draw one less icon (current life is on screen)
            if player and player.alive and not player.isDying and not player.isRespawning then
                 livesToDraw = lives - 1
            -- If player is dying or respawning, draw icons for all remaining lives (lives already decremented)
            elseif player and (player.isDying or player.isRespawning) then
                 livesToDraw = lives
            -- If game over state, draw 0
            elseif gameState == "gameOver" then
                 livesToDraw = 0
            -- Fallback for any other state (shouldn't happen during play/gameover)
            else
                 livesToDraw = lives
            end
        end

        -- Draw the life icons
        for i = 1, livesToDraw do
             -- Draw small ship icons for lives
             local lifeX = 25 + (i * 25); local lifeY = 40
             love.graphics.push(); love.graphics.translate(lifeX, lifeY); love.graphics.rotate(-math.pi / 2) -- Rotate to point up
             love.graphics.polygon("line", 8, 0, -5, -5, -5, 5); -- Simple triangle ship
             love.graphics.pop()
        end
    end

    -- State-specific messages
    if gameState == "title" then
        love.graphics.setFont(titleFont or defaultFont)
        love.graphics.printf("ASTEROIDS", 0, GAME_HEIGHT / 3, GAME_WIDTH, "center")

        love.graphics.setFont(promptFont or defaultFont)
        love.graphics.printf("PRESS ENTER TO START", 0, GAME_HEIGHT / 2 + 20, GAME_WIDTH, "center")
        love.graphics.printf("ARROWS ROTATE THRUST", 0, GAME_HEIGHT - 80, GAME_WIDTH, "center")
        love.graphics.printf("SPACE SHOOT   H HYPERSPACE", 0, GAME_HEIGHT - 50, GAME_WIDTH, "center")

    elseif gameState == "gameOver" then
        love.graphics.setFont(gameOverFont or defaultFont) -- Large font
        love.graphics.printf("GAME OVER", 0, GAME_HEIGHT / 2 - 60, GAME_WIDTH, "center")

        love.graphics.setFont(promptFont or defaultFont)
        love.graphics.printf("FINAL SCORE " .. score, 0, GAME_HEIGHT / 2 + 0, GAME_WIDTH, "center")
        love.graphics.printf("PRESS R TO RESTART", 0, GAME_HEIGHT / 2 + 40, GAME_WIDTH, "center")
    end

    love.graphics.setFont(currentFont) -- Restore original font
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

-- Called repeatedly, handles drawing everything
function love.draw()
    -- Calculate scaling to fit game area into window while maintaining aspect ratio
    local actualW, actualH = love.graphics.getDimensions()
    local scaleX = actualW / GAME_WIDTH
    local scaleY = actualH / GAME_HEIGHT
    local scale = math.min(scaleX, scaleY) -- Use the smaller scale factor

    -- Calculate offsets to center the scaled game area
    local offsetX = (actualW - GAME_WIDTH * scale) / 2
    local offsetY = (actualH - GAME_HEIGHT * scale) / 2

    -- Clear background
    love.graphics.clear(0, 0, 0)

    -- Apply scaling and translation for the main game drawing
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    -- Set line style for retro look (optional)
    love.graphics.setLineStyle("rough")

    -- Define offsets for drawing wrapped objects near edges
    -- This ensures objects wrapping around the screen are drawn correctly on the other side
    local offsets = {
        {0, 0}, {GAME_WIDTH, 0}, {-GAME_WIDTH, 0}, -- Center, right wrap, left wrap
        {0, GAME_HEIGHT}, {0, -GAME_HEIGHT}, -- Bottom wrap, top wrap
        {GAME_WIDTH, GAME_HEIGHT}, {-GAME_WIDTH, GAME_HEIGHT}, -- Corner wraps
        {GAME_WIDTH, -GAME_HEIGHT}, {-GAME_WIDTH, -GAME_HEIGHT}
    }

    -- Draw game objects (only when playing or game over)
    if gameState == "playing" or gameState == "gameOver" then
        -- Draw player (handles normal, dying, respawning, game over fade states internally)
        -- Draw without wrapping offsets if animating or fading, as segments use coordinates relative to a center point.
        -- Draw segments during game over as well (for fade)
        if player and (player.isDying or player.isRespawning or (gameState == "gameOver" and player.deathSegments)) then
            drawPlayer_Internal() -- Draw segments at their calculated positions relative to death/respawn point
        elseif player and player.visible then
             -- Draw normal player with wrapping
             for _, offset in ipairs(offsets) do
                love.graphics.push(); love.graphics.translate(offset[1], offset[2])
                drawPlayer_Internal()
                love.graphics.pop()
            end
        end

        -- Draw other objects with wrapping
        for _, offset in ipairs(offsets) do
            love.graphics.push(); love.graphics.translate(offset[1], offset[2])

            for _, asteroid in ipairs(asteroids) do drawAsteroid_Internal(asteroid) end
            for _, bullet in ipairs(bullets) do drawBullet_Internal(bullet) end

            -- Draw UFO (if active and not leaving) with wrapping
            if ufoActive and ufo and not ufo.leaving then
                 drawUFO_Internal()
            end

            -- Draw particles with wrapping (explosions might happen near edges)
            drawParticles_Internal()

            love.graphics.pop() -- Restore transform for next offset
        end

        -- Draw the UFO separately without offsets if it's in the 'leaving' state (so it flies straight off)
        if ufoActive and ufo and ufo.leaving then
            drawUFO_Internal()
        end
    end

    -- Draw UI elements on top of game objects (score, lives, messages)
    drawUI()

    -- Restore default line style
    love.graphics.setLineStyle("smooth")

    -- Restore original graphics state (remove scaling/translation)
    love.graphics.pop()
end

-- Called when a key is pressed
function love.keypressed(key)
   if key == "escape" then love.event.quit() end -- Quit game

   -- Start game from title screen
   if gameState == "title" and key == "return" then startGame() end

   -- Restart game from game over screen
   if gameState == "gameOver" and key == "r" then startGame() end

   --[[ -- Debug keys (optional)
   if key == "t" then -- Test player explosion sound
       print("Test key 't' pressed - Playing sound: player_explode")
       if sounds.player_explode then sounds.player_explode:stop(); sounds.player_explode:play() end
   end
   if key == "y" then -- Test thrust sound
       print("Test key 'y' pressed - Playing sound: thrust")
       if sounds.thrust then sounds.thrust:stop(); sounds.thrust:play() end
   end
   if key == "p" then -- Test player spawn sound
       print("Test key 'p' pressed - Playing sound: player_spawn")
       if sounds.player_spawn then sounds.player_spawn:stop(); sounds.player_spawn:play() end
   end
   if key == "k" then -- Test player hit manually
       print("Test key 'k' pressed - Simulating player hit")
       if player and player.alive and not player.isDying and not player.isRespawning then playerHit() end
   end
   if key == "g" then -- Test game over sound
       print("Test key 'g' pressed - Playing sound: gameOver")
       if sounds.gameOver then sounds.gameOver:stop(); sounds.gameOver:play() end
   end
    ]]--
end

-- Called when a key is released (not used currently)
function love.keyreleased(key)
    -- Example: Stop thrusting if 'up' is released (handled by isDown in update)
end

-- Called when the window is resized
function love.resize(w, h)
    -- This function is called when the window is resized by the user.
    -- We don't need to do anything here because the drawing logic in love.draw()
    -- already calculates the correct scaling and offset based on the current window dimensions.
    print("Window resized to: " .. w .. "x" .. h)
end
