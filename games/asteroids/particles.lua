-- Particles module for Asteroids
local Particles = {}

-- Import dependencies
local helpers = require("utils.helpers")

-- Constants
local PARTICLE_LIFETIME = 0.5 -- Seconds
local PARTICLE_SPEED = 150 -- Max speed

-- Module variables
local gameWidth, gameHeight
local particles = {}

-- Initialize module
function Particles.init(width, height)
    gameWidth = width
    gameHeight = height
    particles = {}
end

-- Clear all particles
function Particles.clear()
    particles = {}
end

-- Create explosion particles
function Particles.createExplosion(x, y, num)
    if x == nil or y == nil then return false end
    
    for _ = 1, num do
        table.insert(particles, {
            x = x,
            y = y,
            dx = love.math.random() * PARTICLE_SPEED * 2 - PARTICLE_SPEED,
            dy = love.math.random() * PARTICLE_SPEED * 2 - PARTICLE_SPEED,
            lifetime = PARTICLE_LIFETIME * (love.math.random() * 0.5 + 0.75) -- Slight variation
        })
    end
    
    return true
end

-- Update particles
function Particles.update(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        if p then
            -- Update position (no wrapping for particles)
            p.x = p.x + p.dx * dt
            p.y = p.y + p.dy * dt
            
            -- Decrease lifetime
            p.lifetime = p.lifetime - dt
            
            -- Remove if expired
            if p.lifetime <= 0 then
                table.remove(particles, i)
            end
        else
            table.remove(particles, i)
        end
    end
end

-- Draw particles
function Particles.draw()
    for _, p in ipairs(particles) do
        if p and type(p.x) == "number" and type(p.y) == "number" then
            -- Fade out based on remaining lifetime
            local alpha = math.max(0, p.lifetime / PARTICLE_LIFETIME)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.points(p.x, p.y)
        end
    end
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

-- Get particle count
function Particles.getCount()
    return #particles
end

return Particles