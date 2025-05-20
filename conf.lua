function love.conf(t)
    t.title = "Arcade System"
    t.version = "11.5"  
    t.window.width = 800
    t.window.height = 600
    t.window.vsync = true
    t.window.resizable = true
    t.window.minwidth = 400
    t.window.minheight = 300
    t.window.fullscreen = false
    t.window.fullscreentype = "desktop"
    t.window.msaa = 0

    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false 
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = false
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
end