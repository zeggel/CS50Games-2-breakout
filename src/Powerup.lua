Powerup = Class{}

-- -- some of the colors in our palette (to be used with particle systems)
-- paletteColors = {
--     [5] = {
--         ['r'] = 251,
--         ['g'] = 242,
--         ['b'] = 54
--     }
-- }

function Powerup:init(type, x, y)
    self.x = x
    self.y = y
    self.width = 16
    self.height = 16

    self.dy = 30
    self.activated = false
    self.outOfScreen = false

    self.type = type
    self.score = 150

    self:initParticleSystem()
end

function Powerup:initParticleSystem()
    -- particle system belonging to the brick, emitted on hit
    self.psystem = love.graphics.newParticleSystem(gTextures['particle'], 64)

    -- various behavior-determining functions for the particle system
    -- https://love2d.org/wiki/ParticleSystem

    -- lasts between 0.5-1 seconds seconds
    self.psystem:setParticleLifetime(0.5, 1)

    -- give it an acceleration of anywhere between X1,Y1 and X2,Y2 (0, 0) and (80, 80) here
    -- gives generally downward 
    self.psystem:setLinearAcceleration(-15, 0, 15, 80)

    -- spread of particles; normal looks more natural than uniform
    self.psystem:setEmissionArea('normal', 10, 10)
end

function Powerup:update(dt)
    self.y = self.y + self.dy * dt
    if self.y > VIRTUAL_HEIGHT then
        self.outOfScreen = true
    end
    self.psystem:update(dt)
end

function Powerup:collides(target)
    -- first, check to see if the left edge of either is farther to the right
    -- than the right edge of the other
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    -- then check to see if the bottom edge of either is higher than the top
    -- edge of the other
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 

    -- if the above aren't true, they're overlapping
    return true
end

function Powerup:activate()
    self:emit()

    self.activated = true
    gSounds['select']:play()
end

function Powerup:emit()
    -- paletteColors is a global table from Brick class
    self.psystem:setColors(
        paletteColors[5].r / 255,
        paletteColors[5].g / 255,
        paletteColors[5].b / 255,
        55 / 255,
        paletteColors[5].r / 255,
        paletteColors[5].g / 255,
        paletteColors[5].b / 255,
        0
    )
    self.psystem:emit(64)
end

function Powerup:render()
    if not self.activated then
        love.graphics.draw(gTextures['main'], gFrames['powerups'][self.type],
            self.x, self.y)
    end
end

--[[
    Need a separate render function for our particles so it can be called after all bricks are drawn;
    otherwise, some bricks would render over other bricks' particle systems.
]]
function Powerup:renderParticles()
    love.graphics.draw(self.psystem, self.x + 16, self.y + 8)
end