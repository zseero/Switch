require 'rubygems'
require 'gosu'
require 'yaml'

module Z
  Background, PlatformBack, Platform, PlatformOutline, Key, KeyBack,
  PlayerBack, Player, Hint, White = *0...10
end

$normalColors = [
  0xff333333,#black
  0xffff0000,#red
  0xffff8800,#orange
  0xffffee00,#yellow
  0xff00ff00,#green
  0xff00ffff,#aqua
  0xff0000ff,#blue
  0xffff00ff,#purple
  0xffff2288,#brown
  0xffffffff,#white
]
$colors = [
  0xbf333333,#black
  0x5fff0000,#red
  0x5fff8800,#orange
  0x5fffee00,#yellow
  0x5f00ff00,#green
  0x5f00ffff,#aqua
  0x5f0000ff,#blue
  0x5fff00ff,#purple
  0x5fff2288,#brown
  0x7fffffff,#white
]
$faded = 0x5fffffff
#opacity = "7"
#for color in $colors
#  color = ("#{opacity}f" + color).to_i(16)
#  puts color.to_s(16)
#end

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
  def to_s
    "#{@x}:#{@y}"
  end
end

class Quad
  attr_accessor :c1, :c2, :c3, :c4
  def initialize(c1, c2, c3, c4)
    @c1, @c2, @c3, @c4 = c1, c2, c3, c4
  end
  def draw(color, z)
    $window.draw_quad(c1.x, c1.y, color, c2.x, c2.y, color,
                      c3.x, c3.y, color, c4.x, c4.y, color, z)
  end
end

class Window < Gosu::Window
  def initialize
    super(800, 800, false)
    firstLoad
    init
  end
  def firstLoad
  end
  def init
    $window = self
    self.caption = "Switch"
    @background = Gosu::Image.new(self, "lib/background.jpg", false)
    $platformImage = Gosu::Image.new(self, "lib/square2.png", false)
    $platformWidth = (width.to_f / @level.width.to_f).round
    $platformImages = Gosu::Image.load_tiles(self, "lib/whitestreaks.png",
      $platformWidth, $platformWidth, false)
    $hintBox = Gosu::Font.new(self, Gosu::default_font_name, 20)
    $windowSize = Coord.new(width, height)
    @backgroundMult = Coord.new(width.to_f / @background.width.to_f,
                                height.to_f / @background.height.to_f)
    @nums = [Gosu::Kb0, Gosu::Kb1, Gosu::Kb2, Gosu::Kb3, Gosu::Kb4,
             Gosu::Kb5, Gosu::Kb6, Gosu::Kb7, Gosu::Kb8, Gosu::Kb9]
    @whiteOpacity = 255
    @whiteColor = 0xffffffff
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
  def increment; end
  def decrement; end
  def button_down(id)
    char = Gosu::Window.button_id_to_char(id)
    increment if char == '='
    decrement if char == '-'
    checkButtonPresses(id)
  end
  def needs_cursor?
    true
  end
  def update
    if @whiteOpacity >= 0
      o = @whiteOpacity.round.to_s(16)
      o = '0' + o if o.length == 1
      @whiteColor = "#{o}ffffff".to_i(16)
      @whiteOpacity -= 5
    end
    for i in 0...@nums.length
      num = @nums[i]
      @level.index = i if button_down?(num)
    end
    @level.update
    @player.jump if button_down? Gosu::KbUp
    @player.vel_left if button_down? Gosu::KbLeft
    @player.vel_right if button_down? Gosu::KbRight
    @player.vel_down if button_down? Gosu::KbDown
    @player.update
  end
  def draw
    #@background.draw(0, 0, Z::Background, @backgroundMult.x, @backgroundMult.y)
    draw_quad(0, 0, @whiteColor, width, 0, @whiteColor,
              width, height, @whiteColor, 0, height, @whiteColor, Z::White)
    @level.draw
    @player.draw
    for i in 1..8
      color = 0xffffffff
      x = (i - 1) * $platformWidth
      y = 0
      $platformImages[i - 1].draw(x, y, Z::KeyBack,
                    1, 1, color)
      color = $colors[i]
      $window.draw_quad(x, y, color, x + $platformWidth, y, color,
                x + $platformWidth, y + $platformWidth, color, x, y + $platformWidth,
                color, Z::Key)
      $hintBox.draw(i.to_s, x + 5, y, Z::Hint)
    end
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
    @image = Gosu::Image.new(@window, 'lib/sphere.png', false)
    @imageBack = Gosu::Image.new(@window, 'lib/sphereBack.png', false)
    size = (@window.width.to_f / @level.width * 2).round
    @size = Coord.new(size, size)
    $playerSize = @size.dup
    @sizeMult = Coord.new(@size.x.to_f / @image.width.to_f, @size.y.to_f / @image.height.to_f)
    @gravCounter = 0
    @coord = level.playerCoord.dup
    @vel = Coord.new(0.0, 0.0)
    @maxVel = Coord.new(5, 10)
    @velChange = Coord.new(0.5, 0.5)
    @active = Coord.new(false, false)
    @touchingGround = false
    @winner = false
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

  def youWon
  end

  def anyCollisions?(coord = @coord)
    bool = false
    c2 = Coord.new(coord.x + @size.x, coord.y + @size.y)
    @level.layers.each do |layer|
      layer.platforms.each_value do |platform|
        collision = true if platform.collision?(coord, c2)
        bool = true if collision
        @winner = true if collision && platform.colorIndex == 9
      end
    end
    bool
  end

  def collisionCalc(orig)
    @touchingGround = false
    if anyCollisions?
      fy = Coord.new(@coord.x, orig.y)
      fx = Coord.new(orig.x, @coord.y)
      fyWorks = !anyCollisions?(fy)
      fxWorks = !anyCollisions?(fx)
      origWorks = !anyCollisions?(orig)
      @touchingGround = orig.y < @coord.y && !fxWorks
      if fyWorks
        @coord = fy
        @vel.y = 0.0
      elsif fxWorks
        @coord = fx
        @vel.x = 0.0
      elsif origWorks
        @coord = orig
        @vel = Coord.new(0.0, 0.0)
      else
        workingCoord = nil
        i = 0
        while workingCoord.nil?
          i += 1
          coords = [Coord.new(orig.x + i, orig.y),
                    Coord.new(orig.x - i, orig.y),
                    Coord.new(orig.x, orig.y + i),
                    Coord.new(orig.x, orig.y - i)]
          for c in coords
            workingCoord = c if !anyCollisions?(c)
          end
        end
        @coord = workingCoord
        @vel = Coord.new(0.0, 0.0)
        @touchingGround = false
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
    @window.restart if @coord.y > @window.height + 50
    collisionCalc(orig)
    @active = Coord.new(false, false)
    if @winner == true
      youWon
    end
  end

  def draw
    color = $colors[@level.index]
    if @level.index == 0
      color = $colors[9]
    end
    @imageBack.draw @coord.x, @coord.y, Z::PlayerBack, @sizeMult.x, @sizeMult.y
    @image.draw @coord.x, @coord.y, Z::Player, @sizeMult.x, @sizeMult.y, color
    @sparks[@sparkIndex].draw(@coord.x, @coord.y, Z::Player,
      @sizeMult.x, @sizeMult.y, color)
  end
end

class Level
  attr_accessor :name, :layers, :width, :index, :playerCoord, :hint
  def initialize(name, width = 40)
    @name = name
    @width = width
    @hint = ''
    @layers = []
    for i in 0...10
      @layers << Layer.new(i, @width)
    end
    @index = 0
    @saveCounter = 10
    @playerCoord = Coord.new(0, 0)
  end
  def save
  end
  def update
    @saveCounter -= 1
    if @saveCounter <= 0
      save
      @saveCounter = 1000
    end
    for i in 0...@layers.length
      layer = @layers[i]
      layer.addValues
      layer.counter += 1
      if layer.counter > 2#layer.multiplyer
        layer.opacity += layer.direction * layer.multiplyer
        layer.direction *= -1 if Random.rand(0..80) == 0
        layer.direction = 1 if layer.opacity <= layer.minOpacity + layer.multiplyer
        layer.direction = -1 if layer.opacity > layer.maxOpacity
        layer.counter = 0
      end
      layer.update(i == @index || i == 0 || i == 9)
    end
  end
  def draw
    $hintBox.draw(@hint, $platformWidth * 8 + 10, 0, Z::Hint) if @hint
    @layers.each {|layer| layer.draw}
  end
end

class Layer
  attr_accessor :platforms, :opacity, :direction, :counter, :minOpacity, :maxOpacity, :multiplyer
  def initialize(index, width)
    @colorIndex = index
    @platforms = {}
    @showing = false
    @opacity = 0
    @direction = 0
    @counter = 0
  end
  def valid?(x, y)
    x >= 0 && y >= 0
  end
  def addValues
    @minOpacity = 0 if @minOpacity.nil?
    @maxOpacity = 40 if @maxOpacity.nil?
    @multiplyer = 1 if @multiplyer.nil?
    @opacity = Random.rand(0..40) if @opacity.nil?
    @direction = (Random.rand(0..1) * 2) - 1 if @direction.nil?
    @counter = 0 if @counter.nil?
  end
  def update(showing)
    @showing = showing
    @platforms.each_value do |platform|
      platform.update(@showing, @opacity)
    end
  end
  def draw
    @platforms.each_value {|platform| platform.draw}# if @showing
  end
end

class Platform
  attr_accessor :coord, :colorIndex, :freeSides
  attr_reader :size, :realCoord
  def initialize(coord, colorIndex, width)
    @coord = coord
    @colorIndex = colorIndex
    @size = ($windowSize.x.to_f / width.to_f).round
    @multFactor = @size.to_f / $platformImage.width.to_f
    @showing = false
    @opacity = 0
    @freeSides = []
  end
  def collision?(c1, c2)
    amt = 3
    c1, c2 = c1.dup, c2.dup
    c1.x += amt; c1.y += amt
    c2.x -= amt; c2.y -= amt
    return false if !@showing
    coord1 = @realCoord
    coord2 = Coord.new(@realCoord.x + @size, @realCoord.y + @size)
    x1 = c2.x > coord1.x
    y1 = c2.y > coord1.y
    x2 = coord2.x > c1.x
    y2 = coord2.y > c1.y
    x1 && y1 && x2 && y2
  end
  def update(showing, opacity)
    @showing = showing
    @opacity = opacity
    x = @coord.x * @size
    y = $windowSize.y - (@coord.y * @size) - @size
    @realCoord = Coord.new(x, y)
  end
  def getImg(c)
    totalLength = $platformImages.length
    length = Math.sqrt(totalLength)
    c.y = ($windowSize.y - (c.y * @size)) / @size
    i = c.x + c.y * length
    $platformImages[i]
  end
  def createSideQuads
    @sideQuads = []
    topLeft = Coord.new(@realCoord.x, @realCoord.y)
    topRight = Coord.new(@realCoord.x + @size, @realCoord.y)
    bottomRight = Coord.new(@realCoord.x + @size, @realCoord.y + @size)
    bottomLeft = Coord.new(@realCoord.x, @realCoord.y + @size)
    amt = 2
    @freeSides = [] if @freeSides.nil?
    for side in @freeSides
      case side
      when :left
        @sideQuads << Quad.new(Coord.new(topLeft.x, topLeft.y),
                               Coord.new(topLeft.x + amt, topLeft.y),
                               Coord.new(bottomLeft.x + amt, bottomLeft.y),
                               Coord.new(bottomLeft.x, bottomLeft.y))
      when :right
        @sideQuads << Quad.new(Coord.new(topRight.x - amt, topRight.y),
                               Coord.new(topRight.x, topRight.y),
                               Coord.new(bottomRight.x, bottomRight.y),
                               Coord.new(bottomRight.x - amt, bottomRight.y))
      when :top
        @sideQuads << Quad.new(Coord.new(topLeft.x, topLeft.y),
                               Coord.new(topRight.x, topRight.y),
                               Coord.new(topRight.x, topRight.y + amt),
                               Coord.new(topLeft.x, topLeft.y + amt))
      when :bottom
        @sideQuads << Quad.new(Coord.new(bottomLeft.x, bottomLeft.y - amt),
                               Coord.new(bottomRight.x, bottomRight.y - amt),
                               Coord.new(bottomRight.x, bottomRight.y),
                               Coord.new(bottomLeft.x, bottomLeft.y))
      end
    end
  end
  def drawSideQuads
    color = $normalColors[@colorIndex]
    createSideQuads if @sideQuads.nil?
    for quad in @sideQuads
      quad.draw(color, Z::PlatformOutline)
    end
  end
  def getOpacity(xopacity, color)
    color = $colors[@colorIndex]
    color = color.to_s(16)[2..-1]
    puts xopacity.class if xopacity.class != Fixnum
    o = xopacity.to_s(16)
    o = '0' + o if o.length == 1
    color = (o + color).to_i(16)
  end
  def draw
    #drawSideQuads if @showing
    @opacity = 0 if @opacity.nil?
    color = 0xffffffff
    color = getOpacity(@opacity, color) if !@showing
    getImg(@coord.dup).draw(@realCoord.x, @realCoord.y, Z::PlatformBack,
                  1, 1, color)
    color = $colors[@colorIndex]
    color = getOpacity(@opacity / 2, color)if !@showing
    $window.draw_quad(@realCoord.x, @realCoord.y, color, @realCoord.x + @size, @realCoord.y, color,
              @realCoord.x + @size, @realCoord.y + @size, color, @realCoord.x, @realCoord.y + @size,
              color, Z::Platform)
  end
end