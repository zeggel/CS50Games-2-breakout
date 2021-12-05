--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

local TOTAL_SECONDS_BEFORE_POWERUP = 20

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = {params.ball}
    self.ballsCount = 1
    self.level = params.level

    self.powerups = {}
    self.secondsBeforePowerup = TOTAL_SECONDS_BEFORE_POWERUP
    self.recoverPoints = 5000

    -- give ball random starting velocity
    for k, ball in pairs(self.balls) do
        ball.dx = math.random(-200, 200)
        ball.dy = math.random(-50, -60)
    end
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    for k, ball in pairs(self.balls) do
        ball:update(dt)
        if ball:collides(self.paddle) then
            ball:interactWithPaddle(self.paddle)
            gSounds['paddle-hit']:play()
        end
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do

        for k, ball in pairs(self.balls) do
            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then

                -- trigger the brick's hit function, which removes it from play
                if brick.blocked then
                    if ball.hasKey then
                        ball.hasKey = false
                        
                        self.score = self.score + 100

                        brick:unlock()
                    end
                else
                    -- add to score
                    self.score = self.score + (brick.tier * 200 + brick.color * 25)

                    brick:hit()
                end

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- multiply recover points by 2
                    self.recoverPoints = self.recoverPoints + math.min(100000, self.recoverPoints * 2)

                    self:recoverHealth()
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = self.balls[1],
                        recoverPoints = self.recoverPoints
                    })
                end

                -- Spawns powerup
                if not brick.inPlay then
                    self:spawnBrickPowerup(brick)
                    self.secondsBeforePowerup = TOTAL_SECONDS_BEFORE_POWERUP
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    local filteredBalls = {}
    for k, ball in pairs(self.balls) do
        if ball.y >= VIRTUAL_HEIGHT then
            self.ballsCount = self.ballsCount - 1
        else
            table.insert(filteredBalls, ball)
        end
    end
    self.balls = filteredBalls

    if self.ballsCount == 0 then
        self:loseHealth()
        
        if self.health == 0 then
            gStateMachine:change('game-over', {
                score = self.score,
                highScores = self.highScores
            })
        else
            self.paddle:reset()
            gStateMachine:change('serve', {
                paddle = self.paddle,
                bricks = self.bricks,
                health = self.health,
                score = self.score,
                highScores = self.highScores,
                level = self.level,
                recoverPoints = self.recoverPoints
            })
        end
    end

    self.secondsBeforePowerup = self.secondsBeforePowerup - dt
    if self.secondsBeforePowerup < 0 then
        self.secondsBeforePowerup = TOTAL_SECONDS_BEFORE_POWERUP
        self:spawnTimePowerup()
    end

    for _, powerup in pairs(self.powerups) do
        powerup:update(dt)
        if not powerup.activated and powerup:collides(self.paddle) then
            self.score = self.score + powerup.score
            self:activatePowerup(powerup)
        end
    end
    self:filterPowerups()

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    for k, ball in pairs(self.balls) do
        ball:render()
    end

    for _, powerup in pairs(self.powerups) do
        powerup:render()
        powerup:renderParticles()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:loseHealth()
    self.health = self.health - 1
    gSounds['hurt']:play()
end

function PlayState:recoverHealth()
    -- can't go above 3 health
    self.health = math.min(3, self.health + 1)
    -- play recover sound effect
    gSounds['recover']:play()
end

function PlayState:activatePowerup(powerup)
    if powerup.type == 3 then
        self:recoverHealth()
    elseif powerup.type == 4 then
        self:loseHealth()
    elseif powerup.type == 5 then
        for _, ball in pairs(self.balls) do
            ball:increaseSpeed()
        end
    elseif powerup.type == 6 then
        for _, ball in pairs(self.balls) do
            ball:decreaseSpeed()
        end
    elseif powerup.type == 7 then
        self.paddle:shrink()
    elseif powerup.type == 8 then
        self.paddle:grow()
    elseif powerup.type == 9 then
        self:spawnExtraBalls(2)
    elseif powerup.type == 10 then
        for _, ball in pairs(self.balls) do
            ball.hasKey = true
        end
    end

    powerup:activate()
end

function PlayState:spawnExtraBalls(count)
    for i = 1, count do
        local newBall = Ball(math.random(4))
        newBall:reset()
        newBall.dx = math.random(-200, 200)
        newBall.dy = math.random(-50, -60)
        table.insert(self.balls, newBall)
        self.ballsCount = self.ballsCount + 1
    end
end

function PlayState:filterPowerups()
    local filtered = {}
    for _, powerup in pairs(self.powerups) do
        if not powerup.outOfScreen then
            table.insert(filtered, powerup)
        end
    end
    self.powerups = filtered
end

function PlayState:spawnBrickPowerup(brick)
    local function generateType()
        local probability = math.random(100)
        if probability < 15 then
            return 3
        elseif probability < 20 then
            return 4
        elseif probability < 25 then
            return 7
        elseif probability < 30 then
            return 8
        elseif probability < 35 then
            return 5
        elseif probability < 40 then
            return 6
        elseif probability < 45 then
            return 9
        elseif probability < 90 and self:hasBlockedBrick() then
            return 10
        end

        return 0
    end

    local powerupType = generateType()
    if powerupType > 0 then
        local powerupX = brick.x + 8
        table.insert(self.powerups, Powerup(powerupType, powerupX, brick.y))
    end
end

function PlayState:spawnTimePowerup()
    local function hasBallWithKey()
        for _, ball in pairs(self.balls) do
            if ball.hasKey then
                return true
            end
        end
        return false
    end

    local powerupType
    if self:hasBlockedBrick() and not hasBallWithKey() then
        powerupType = 10
    else
        local types = {5, 8, 9}
        powerupType = types[math.random(#types)]
    end
    local powerupX = math.random(20, VIRTUAL_WIDTH - 20)
    table.insert(self.powerups, Powerup(powerupType, powerupX, -20))
end

function PlayState:hasBlockedBrick()
    for _, brick in pairs(self.bricks) do
        if brick.blocked then
            return true
        end
    end
    return false
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end