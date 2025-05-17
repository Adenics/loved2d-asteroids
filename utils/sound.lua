-- Sound generation utilities
local sound = {}

-- Generates sound effects programmatically
function sound.generateSounds()
    local sounds = {}
    local sampleRate = 22050 -- Standard sample rate for retro sounds
    local bitDepth = 16     -- Standard bit depth
    local channels = 1      -- Mono sound effects
    local success, result

    -- Dummy sound object to prevent errors if sound generation fails
    local dummySound = {
        play = function() end,
        stop = function() end,
        isPlaying = function() return false end,
        setLooping = function() end,
        setVolume = function() end,
        clone = function() return dummySound end
    }

    -- Helper function to create a LÖVE Source from SoundData, with error handling
    local function createSource(data, type)
        local suc, src = pcall(love.audio.newSource, data, type)
        if suc then
            return src
        else
            print("ERROR creating sound source: ", src)
            return dummySound
        end
    end

    -- Thrust (Low rumble with LFO for a pulsating effect)
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
            fireData:setSample(i, math.sin(t * freq * math.pi * 2) * 0.4 * (1 - t * 0.8))
        end
        sounds.shoot = createSource(fireData, "static")
    else
        print("ERROR creating shoot SoundData:", result)
        sounds.shoot = dummySound
    end

    -- Generic Explosion (White noise burst with decay, for asteroids)
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

    -- Player Explode (Atari-style: short, punchy, noise-based)
    local deathDurationSeconds = 0.6
    local deathDurationSamples = math.floor(sampleRate * deathDurationSeconds)
    success, result = pcall(love.sound.newSoundData, deathDurationSamples, sampleRate, bitDepth, channels)
    if success then
        local deathData = result
        local initialVolume = 0.9
        local noisePitchStart = 1.0
        local noisePitchEnd = 0.3
        for i = 0, deathData:getSampleCount() - 1 do
            local t = i / deathDurationSamples
            local sampleValue = 0
            local envelope = math.pow(1 - t, 3) * initialVolume
            local currentPitchEffect = noisePitchStart * (1-t) + noisePitchEnd * t
            local noisySample = (love.math.random() * 2 - 1)
            sampleValue = noisySample * currentPitchEffect
            sampleValue = sampleValue * envelope
            if t > 0.1 and t < 0.25 then
                local popEnvelope = math.sin(( (t - 0.1) / (0.25 - 0.1) ) * math.pi)
                sampleValue = sampleValue + (love.math.random() * 2 - 1) * 0.3 * popEnvelope
            end
            sampleValue = math.max(-1, math.min(1, sampleValue))
            deathData:setSample(i, sampleValue)
        end
        sounds.player_explode = createSource(deathData, "static")
    else
        print("ERROR creating player_explode SoundData:", result)
        sounds.player_explode = dummySound
    end

    -- Player Spawn (Series of clicks)
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
                if i < playerSpawnSampleCount then
                    local t_click = (i - clickStartSample) / (clickEndSample - clickStartSample + 1)
                    local clickAmp = 0.3 * (1 - t_click)
                    spawnData:setSample(i, (love.math.random() * 2 - 1) * clickAmp)
                end
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

    -- Game Over (Descending arpeggio only)
    local gameOverDurationSeconds = 1.5 -- Adjusted duration for arpeggio only
    local gameOverSampleCount = math.floor(sampleRate * gameOverDurationSeconds)
    success, result = pcall(love.sound.newSoundData, gameOverSampleCount, sampleRate, bitDepth, channels)
    if success then
        local gameOverData = result
        local overallVolume = 0.8 -- Slightly increased volume as it's the only component

        -- Descending Arpeggio (e.g., C minor: G, Eb, C)
        local arpeggioNotes = {
            {freq = 392.00, duration = 0.4, volume = 0.9}, -- G4
            {freq = 311.13, duration = 0.4, volume = 0.8}, -- Eb4
            {freq = 261.63, duration = 0.5, volume = 0.7}  -- C4
        }
        local currentSampleOffset = 0

        for i = 0, gameOverSampleCount - 1 do -- Initialize all samples to 0
            gameOverData:setSample(i, 0)
        end

        for noteIdx, noteInfo in ipairs(arpeggioNotes) do
            local noteDurationSamples = math.floor(sampleRate * noteInfo.duration)
            local noteEndTimeSamples = currentSampleOffset + noteDurationSamples
            
            for i = currentSampleOffset, math.min(noteEndTimeSamples - 1, gameOverSampleCount - 1) do
                local t_note = (i - currentSampleOffset) / noteDurationSamples -- Time within this note
                local envelope = math.pow(1 - t_note, 1.5) -- Exponential decay for the note
                local sampleValue = math.sin((i / sampleRate) * noteInfo.freq * 2 * math.pi) * noteInfo.volume * envelope
                
                local existingSample = gameOverData:getSample(i) -- Should be 0 if initialized correctly
                gameOverData:setSample(i, existingSample + sampleValue * overallVolume)
            end
            currentSampleOffset = noteEndTimeSamples
        end
        
        -- Final normalization pass to prevent clipping
        for i = 0, gameOverSampleCount - 1 do
            local s = gameOverData:getSample(i)
            gameOverData:setSample(i, math.max(-1, math.min(1, s)))
        end

        sounds.gameOver = createSource(gameOverData, "static")
    else
        print("ERROR creating gameOver SoundData:", result)
        sounds.gameOver = dummySound
    end

    -- Menu Select Beep (New Sound)
    local menuSelectDurationSeconds = 0.07 -- Very short
    local menuSelectSampleCount = math.floor(sampleRate * menuSelectDurationSeconds)
    success, result = pcall(love.sound.newSoundData, menuSelectSampleCount, sampleRate, bitDepth, channels)
    if success then
        local menuSelectData = result
        local beepFreq = 880.00 -- A5 note, a clear beep
        local beepVolume = 0.5
        for i = 0, menuSelectData:getSampleCount() - 1 do
            local t = i / menuSelectData:getSampleCount()
            -- Simple envelope: quick attack, slightly longer decay
            local envelope = 0
            if t < 0.2 then -- Attack phase (20% of duration)
                envelope = t / 0.2
            else -- Decay phase (remaining 80%)
                envelope = 1 - ((t - 0.2) / 0.8)
            end
            envelope = math.max(0, envelope) -- Ensure envelope doesn't go negative
            
            local sampleValue = math.sin( (i / sampleRate) * beepFreq * 2 * math.pi) * beepVolume * envelope
            menuSelectData:setSample(i, sampleValue)
        end
        sounds.menu_select = createSource(menuSelectData, "static")
    else
        print("ERROR creating menu_select SoundData:", result)
        sounds.menu_select = dummySound
    end

    return sounds
end

return sound