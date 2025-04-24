-- Sound generation utilities
local sound = {}

-- Generates sound effects programmatically
function sound.generateSounds()
    local sounds = {}
    local sampleRate = 22050
    local bitDepth = 16
    local channels = 1
    local success, result

    -- Dummy sound object to prevent errors if generation fails
    local dummySound = { 
        play = function() end, 
        stop = function() end, 
        isPlaying = function() return false end, 
        setLooping = function() end, 
        setVolume = function() end, 
        clone = function() return dummySound end 
    }

    -- Helper to create a Source from SoundData, with error handling
    local function createSource(data, type)
        local suc, src = pcall(love.audio.newSource, data, type)
        if suc then 
            return src 
        else 
            print("ERROR creating source:", src)
            return dummySound 
        end
    end

    -- Thrust (Low rumble with LFO)
    local thrustDurationSamples = sampleRate * 2 -- 2 seconds loop
    success, result = pcall(love.sound.newSoundData, thrustDurationSamples, sampleRate, bitDepth, channels)
    if success then
        local thrustData = result
        local base_volume = 0.15
        local lfo_freq = 0.7
        local lfo_depth = 0.2
        for i = 0, thrustData:getSampleCount() - 1 do
            local lfo_phase = (i / sampleRate) * lfo_freq * 2 * math.pi
            local volume_mod = (1.0 - lfo_depth) + lfo_depth * (math.sin(lfo_phase) * 0.5 + 0.5)
            local sampleValue = (love.math.random() * 2 - 1) * base_volume * volume_mod
            thrustData:setSample(i, sampleValue)
        end
        sounds.thrust = createSource(thrustData, "static")
        sounds.thrust:setLooping(true)
    else 
        print("ERROR creating thrust SoundData:", result)
        sounds.thrust = dummySound 
    end

    -- Player Shoot (Downward pitch sweep)
    success, result = pcall(love.sound.newSoundData, 4096, sampleRate, bitDepth, channels)
    if success then
        local fireData = result
        for i = 0, fireData:getSampleCount() - 1 do
            local t = i / fireData:getSampleCount()
            local freq = 1200 - 800 * t
            fireData:setSample(i, math.sin(t * freq * math.pi * 2) * 0.4 * (1 - t*0.8))
        end
        sounds.shoot = createSource(fireData, "static")
    else 
        print("ERROR creating shoot SoundData:", result)
        sounds.shoot = dummySound 
    end

    -- Explosion (White noise burst with decay)
    success, result = pcall(love.sound.newSoundData, 8192, sampleRate, bitDepth, channels)
    if success then
        local explosionData = result
        for i = 0, explosionData:getSampleCount() - 1 do
            local t = i / explosionData:getSampleCount()
            explosionData:setSample(i, (love.math.random() * 2 - 1) * (1 - t) * 0.5)
        end
        sounds.explosion = createSource(explosionData, "static")
    else 
        print("ERROR creating explosion SoundData:", result)
        sounds.explosion = dummySound 
    end

    -- Player Explode (Multiple decaying noise bursts)
    local deathDurationSamples = 22050 -- 1 second
    success, result = pcall(love.sound.newSoundData, deathDurationSamples, sampleRate, bitDepth, channels)
    if success then
        local deathData = result
        local numBooms = 4
        local silenceFraction = 0.01
        local totalCycleSamples = math.floor(deathDurationSamples / numBooms)
        local boomSamples = math.floor(totalCycleSamples * (1 - silenceFraction))
        local initialVolume = 0.75
        for i = 0, deathData:getSampleCount() - 1 do
            local currentCycleIndex = math.min(math.floor(i / totalCycleSamples), numBooms - 1)
            local sampleInCycle = i % totalCycleSamples
            local sampleValue = 0
            if sampleInCycle < boomSamples then
                local volumeMultiplier = ((numBooms - currentCycleIndex) / numBooms)^2
                local currentVolume = initialVolume * math.max(0, volumeMultiplier)
                sampleValue = (love.math.random() * 2 - 1) * currentVolume
            end
            deathData:setSample(i, sampleValue)
        end
        sounds.player_explode = createSource(deathData, "static")
    else 
        print("ERROR creating player_explode SoundData:", result)
        sounds.player_explode = dummySound 
    end

    -- Player Spawn (Clicks)
    local playerSpawnSampleCount = math.floor(sampleRate * 0.7)
    success, result = pcall(love.sound.newSoundData, playerSpawnSampleCount, sampleRate, bitDepth, channels)
    if success then
        local spawnData = result
        local numClicks = 3
        local clickDuration = 0.05
        local clickInterval = 0.08
        
        for c = 1, numClicks do
            local clickStartSample = math.floor((c - 1) * clickInterval * sampleRate)
            local clickEndSample = math.min(clickStartSample + clickDuration * sampleRate, playerSpawnSampleCount - 1)
            for i = clickStartSample, clickEndSample do
                local t = (i - clickStartSample) / (clickEndSample - clickStartSample + 1)
                local clickAmp = 0.3 * (1 - t)
                spawnData:setSample(i, (love.math.random() * 2 - 1) * clickAmp)
            end
        end

        sounds.player_spawn = createSource(spawnData, "static")
    else 
        print("ERROR creating player_spawn SoundData:", result)
        sounds.player_spawn = dummySound 
    end

    -- UFO Spawn (Short high beep)
    success, result = pcall(love.sound.newSoundData, 4410, sampleRate, bitDepth, channels)
    if success then
        local spawnData = result
        for i = 0, spawnData:getSampleCount() - 1 do
            local t = i / spawnData:getSampleCount()
            spawnData:setSample(i, math.sin(t * 900 * math.pi * 2) * 0.3 * (1-t))
        end
        sounds.ufo_spawn = createSource(spawnData, "static")
    else 
        print("ERROR creating ufo_spawn SoundData:", result)
        sounds.ufo_spawn = dummySound 
    end

    -- UFO Flying (Siren sound)
    success, result = pcall(love.sound.newSoundData, sampleRate, sampleRate, bitDepth, channels)
    if success then
        local flyingData = result
        local baseFreq = 800
        local lfoFreq = 1.5
        local lfoDepth = 300
        local amplitude = 0.25

        for i = 0, flyingData:getSampleCount() - 1 do
            local time = i / sampleRate
            local lfoVal = math.sin(time * lfoFreq * math.pi * 2)
            local currentFreq = baseFreq + lfoVal * lfoDepth
            flyingData:setSample(i, math.sin(time * currentFreq * math.pi * 2) * amplitude)
        end
        sounds.ufo_flying = createSource(flyingData, "static")
        sounds.ufo_flying:setLooping(true)
    else 
        print("ERROR creating ufo_flying SoundData:", result)
        sounds.ufo_flying = dummySound 
    end

    -- UFO Shoot
    success, result = pcall(love.sound.newSoundData, 4096, sampleRate, bitDepth, channels)
    if success then
        local ufoShootData = result
        for i = 0, ufoShootData:getSampleCount() - 1 do
            local t = i / ufoShootData:getSampleCount()
            local freq = 1400 - 700 * t
            ufoShootData:setSample(i, math.sin(t * freq * math.pi * 2) * 0.4 * (1 - t*0.8))
        end
        sounds.ufo_shoot = createSource(ufoShootData, "static")
    else 
        print("ERROR creating ufo_shoot SoundData:", result)
        sounds.ufo_shoot = dummySound 
    end

    -- Hyperspace (Weird rising/falling pitch)
    success, result = pcall(love.sound.newSoundData, 8820, sampleRate, bitDepth, channels)
    if success then
        local hyperData = result
        for i = 0, hyperData:getSampleCount() - 1 do
            local t = i / hyperData:getSampleCount()
            local freq = 400 + 1200 * math.sin(t * math.pi)
            hyperData:setSample(i, math.sin(t * freq * math.pi * 2) * 0.3 * (1-t))
        end
        sounds.hyperspace = createSource(hyperData, "static")
    else 
        print("ERROR creating hyperspace SoundData:", result)
        sounds.hyperspace = dummySound 
    end

    -- Game Over (Long decaying low tone)
    success, result = pcall(love.sound.newSoundData, 65536, sampleRate, bitDepth, channels)
    if success then
        local gameOverData = result
        for i = 0, gameOverData:getSampleCount() - 1 do
            local t = i / gameOverData:getSampleCount()
            local freq = 220 * (1 - t * 0.98)
            local amplitude = 0.8 * (1 - t * 0.8)
            gameOverData:setSample(i, math.sin(t * freq * math.pi * 2) * amplitude)
        end
        sounds.gameOver = createSource(gameOverData, "static")
    else 
        print("ERROR creating gameOver SoundData:", result)
        sounds.gameOver = dummySound 
    end

    return sounds
end

return sound