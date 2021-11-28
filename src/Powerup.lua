Powerup = Class{}

function Powerup:init(skin)
    self.width = 10
    self.height = 10

    self.dy = 30

    self.skin = skin
    
    self:reset()
end

function Powerup:reset()
    self.x = math.random(10, VIRTUAL_WIDTH - self.width - 10)
    self.y = -self.height
end

function Powerup:update(dt)
    self.y = self.y + self.dy * dt
end

function Powerup:render()
    love.graphics.draw(gTextures['main'], gFrames['powerups'][self.skin],
        self.x, self.y)
end