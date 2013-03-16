require 'rubygems'
require 'gosu'
require 'yaml'

module Z
  Background, PlatformBack, Platform, PlayerBack, Player = *0...5
end

$colors = [
  0xff333333,#black
  0xffff0000,#red
  0xffff8800,#orange
  0xffffff00,#yellow
  0xff00ff00,#green
  0xff00ffff,#aqua
  0xff0000ff,#blue
  0xffff00ff,#purple
  0xff333333,#black
  0xff333333,#black
]

module Mode
  Menu, Play = *0..1
end

class Coord
  attr_accessor :x, :y
  def initialize(x, y)
    @x, @y = x, y
  end
  def dup
    Coord.new(@x, @y)
  end
  def ==(c)
    (@x == c.x && @y == c.y)
  end
end

class Window < Gosu::Window
  def initialize
    super(800, 800, false)
    init
  end
  def init
    self.caption = "Switch"
    restart
  end
  def restart
    @player = Player.new(self, @level)
  end
  def checkButtonPresses(id)
    if id == Gosu::KbEnter || id == Gosu::KbSpace
      restart
    end
    if id == Gosu::KbEscape
      exit
    end
  end
  def button_down(id)
    checkButtonPresses(id)
  end
  def needs_cursor?
    true
  end
  def update
    @level.update
    @player.jump if button_down? Gosu::KbUp
    @player.vel_left if button_down? Gosu::KbLeft
    @player.vel_right if button_down? Gosu::KbRight
    @player.vel_down if button_down? Gosu::KbDown
    @player.update
  end
  def draw
    @level.draw
    @player.draw
  end
end

class Player
  attr_reader :coord, :vel, :size, :touchingGround
  def initialize(window, level)
    @window = window
    @level = level
    sparkNames = ['spark1.png', 'spark2.png', 'spark2.png', 'spark3.png', 'spark4.png', 'spark5.png']
    @sparkIndex = 0
    @sparkCounter = 0
    @sparks = []
    for name in sparkNames
      @sparks << Gosu::Image.new(@window, 'lib/' + name, false)
    end
    @image = Gosu::Image.new(@window, "lib/sphere.png", false)
    @imageBack = Gosu::Image.new(@window, "lib/sphereBack.png", false)
    size = (@window.width.to_f / @level.width * 2).round
    @size = Coord.new(size, size)
    @sizeMult = Coord.new(@size.x.to_f / @image.width.to_f, @size.y.to_f / @image.height.to_f)
    @gravCounter = 0
    @coord = level.playerCoord.dup
    @vel = Coord.new(0.0, 0.0)
    @maxVel = Coord.new(5, 10)
    @velChange = Coord.new(0.5, 0.5)
    @active = Coord.new(false, false)
    @touchingGround = false
  end

  def jump
    @vel.y = -10 if @touchingGround
  end
  def vel_up
    @active.y = true
    @vel.y -= @velChange.y if @vel.y.abs < @maxVel.y
  end
  def vel_down
    @active.y = true
    @vel.y += @velChange.y if @vel.y.abs < @maxVel.y
  end
  def vel_left
    @active.x = true
    @vel.x -= @velChange.x if @vel.x.abs < @maxVel.x
  end
  def vel_right
    @active.x = true
    @vel.x += @velChange.x if @vel.x.abs < @maxVel.x
  end

  def touchingWall?; @coord.x < 0 || @coord.x > @window.width - @size.x; end

  def anyCollisions?(coord = @coord)
    bool = false
    c2 = Coord.new(coord.x + @size.x, coord.y + @size.y)
    @level.layers.each do |layer|
      layer.platforms.each_value do |platform|
        bool = true if platform.collision?(coord, c2)
      end
    end
    bool
  end

  def collisionCalc(orig)
    @touchingGround = false
    if anyCollisions?
      @touchingGround = orig.y < @coord.y
      fy = Coord.new(@coord.x, orig.y)
      fx = Coord.new(orig.x, @coord.y)
      fyWorks = !anyCollisions?(fy)
      fxWorks = !anyCollisions?(fx)
      if fyWorks
        @coord = fy
        @vel.y = 0.0
      elsif fxWorks
        @coord = fx
        @vel.x = 0.0
      else
        @coord = orig
        @vel = Coord.new(0.0, 0.0)
      end
    end
    @vel.x = 0.0 if @touchingGround && !@active.x
  end

  def gravity
    if @vel.y < 30
      @gravCounter = 0
      @vel.y += 0.5
    end
    @gravCounter += 1
  end
  
  def update
    if @sparkCounter > 3
      @sparkIndex += 1
      @sparkIndex %= @sparks.length
      @sparkCounter = 0
    end
    @sparkCounter += 1
    orig = @coord.dup
    gravity
    @coord.x += @vel.x
    @coord.y += @vel.y
    @vel.x *= 0.95
    if touchingWall?
      @coord.x = orig.x
      @vel.x = 0.0
    end
    collisionCalc(orig)
    @active = Coord.new(false, false)
  end

  def draw
    @imageBack.draw @coord.x, @coord.y, Z::PlayerBack, @sizeMult.x, @sizeMult.y
    @image.draw @coord.x, @coord.y, Z::Player, @sizeMult.x, @sizeMult.y, $colors[@level.index]
    @sparks[@sparkIndex].draw(@coord.x, @coord.y, Z::Player,
      @sizeMult.x, @sizeMult.y, $colors[@level.index])
  end
end

class Level
  attr_accessor :layers, :width, :index, :playerCoord
  def initialize(window, name, startLayers = [], width = 40)
    @window = window
    @name = name
    @width = width
    @layers = []
    10.times do
      @layers << Layer.new(@window)
    end
    for i in 0...startLayers.length
      layer = startLayers[i]
      for coord in layer
        parts = coord.split(':')
        c = Coord.new(parts[0].to_i, parts[1].to_i)
        s = "#{c.x}:#{c.y}"
        @layers[i].platforms[s] = Platform.new(@window, c, i, @width)
      end
    end
    @index = 0
    @saveCounter = 0
    @playerCoord = Coord.new(0, 0)
    @nums = [Gosu::Kb0, Gosu::Kb1, Gosu::Kb2, Gosu::Kb3, Gosu::Kb4,
             Gosu::Kb5, Gosu::Kb6, Gosu::Kb7, Gosu::Kb8, Gosu::Kb9]
  end
  def indexChange
    for i in 0...@nums.length
      num = @nums[i]
      @index = i if @window.button_down?(num)
    end
  end
  def save
  end
  def update
    @saveCounter += 1
    if @saveCounter > 100
      save
      @saveCounter = 0
    end
    indexChange
    for i in 0...@layers.length
      layer = @layers[i]
      layer.update(i == @index || i == 0)
    end
  end
  def draw
    @layers.each {|layer| layer.draw}
  end
end

class Layer
  attr_accessor :platforms
  def initialize(window)
    @window = window
    @platforms = {}
    @showing = false
  end
  def update(showing)
    @showing = showing
    @platforms.each_value {|platform| platform.update(@showing)}
  end
  def draw
    @platforms.each_value {|platform| platform.draw} if @showing
  end
end

class Platform
  attr_accessor :coord, :colorIndex
  attr_reader :size
  def initialize(window, coord, colorIndex, width)
    @window = window
    @coord = coord
    @colorIndex = colorIndex
    @size = (@window.width.to_f / width.to_f).round
    @multFactor = @size.to_f / @image.width.to_f
    @showing = false
    @image = Gosu::Image.new(self, "lib/square2.png", false)
  end
  def collision?(c1, c2)
    return false if !@showing
    coord1 = @realCoord
    coord2 = Coord.new(@realCoord.x + @size, @realCoord.y + @size)
    x1 = c2.x > coord1.x
    y1 = c2.y > coord1.y
    x2 = coord2.x > c1.x
    y2 = coord2.y > c1.y
    x1 && y1 && x2 && y2
  end
  def update(showing)
    @showing = showing
    x = @coord.x * @size
    y = @window.height - (@coord.y * @size) - @size
    @realCoord = Coord.new(x, y)
  end
  def draw
    @image.draw(@realCoord.x, @realCoord.y, Z::Platform, @multFactor, @multFactor, $colors[@colorIndex])
  end
end