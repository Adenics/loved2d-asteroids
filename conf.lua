
function love.conf(t)
    t.title = "Asteroids" -- Window title
    t.version = "11.5"  -- Target LÖVE version (ensure compatibility)
    t.window.width = 800 -- Initial window width
    t.window.height = 600 -- Initial window height
    t.window.vsync = true -- Enable vsync to prevent screen tearing (recommended)

    t.window.resizable = true -- Allow window resizing
    t.window.minwidth = 400 -- Minimum allowed window width
    t.window.minheight = 300 -- Minimum allowed window height

    t.window.fullscreen = false -- Start in windowed mode
    t.window.fullscreentype = "desktop" -- Use desktop resolution for fullscreen

    t.window.msaa = 0 -- Antialiasing (0 = off, higher values = smoother lines but more GPU load)

    -- Enable necessary LÖVE modules
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true -- Though not used directly, good to have
    t.modules.joystick = false -- Disable if not needed
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true -- Might be useful for menus later
    t.modules.physics = false -- Not using LÖVE's physics engine
    t.modules.sound = true -- Needed for generated sounds
    t.modules.system = true
    t.modules.thread = false -- Disable if not needed
    t.modules.timer = true
    t.modules.touch = false -- Disable if not needed
    t.modules.video = false -- Disable if not needed
    t.modules.window = true
end