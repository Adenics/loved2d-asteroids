local Particles = {}

local helpers = require("utils.helpers")

local PARTICLE_LIFETIME = 0.5 
local PARTICLE_SPEED = 150 

local gameWidth, gameHeight
local particles = {}

function Particles.init(width, height)
    gameWidth = width
    gameHeight = height
    particles = {}
end

function Particles.clear()
    particles = {}
end

function Particles.createExplosion(x, y, num)
    if x == nil or y == nil then return false end

    for _ = 1, num do
        table.insert(particles, {
            x = x,
            y = y,
            dx = love.math.random() * PARTICLE_SPEED * 2 - PARTICLE_SPEED,
            dy = love.math.random() * PARTICLE_SPEED * 2 - PARTICLE_SPEED,
            lifetime = PARTICLE_LIFETIME * (love.math.random() * 0.5 + 0.75) 
        })
    end

    return true
end

function Particles.update(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        if p then

            p.x = p.x + p.dx * dt
            p.y = p.y + p.dy * dt

            p.lifetime = p.lifetime - dt

            if p.lifetime <= 0 then
                table.remove(particles, i)
            end
        else
            table.remove(particles, i)
        end
    end
end

function Particles.draw()
    for _, p in ipairs(particles) do
        if p and type(p.x) == "number" and type(p.y) == "number" then

            local alpha = math.max(0, p.lifetime / PARTICLE_LIFETIME)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.points(p.x, p.y)
        end
    end
    love.graphics.setColor(1, 1, 1, 1) 
end

function Particles.getCount()
    return #particles
end

return Particles