#!/usr/bin/env ruby
#run the following to package this application:
#ocra --window --chdir-first "Switch.rb" lib/*
#--icon "SlimeWarzIcon.ico"

puts "Loading Switch..."
require 'rubygems'
require 'gosu'

module Z
  Background, Platform, Player = *0...3
end

$colors = [
  0xff333333,#black
  0xffff0000,#red
  0xffff8800,#orange
  0xffffff00,#yellow
  0xff00ff00,#green
  0xff00ffff,#aqua
  0xff0000ff,#blue
  0xffff00ff, #purple
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
    super(500, 800, false)
    self.caption = "Switch"
    @level = Level.new(self)
    restart
  end
  def restart
    #@level = Level.new(self)
    @player = Player.new(self, @level)
  end
  def button_down(id)
    if id == Gosu::KbEnter || id == Gosu::KbSpace
      restart
    end
    if id == Gosu::KbEscape
      exit
    end
    if id == Gosu::MsLeft
      x, y = mouse_x, height - mouse_y
      size = (width / @level.width).round
      x = (x / size).to_i
      y = (y / size).to_i
      c = Coord.new(x, y)
      layer = @level.layers[@level.index]
      s = "#{c.x}:#{c.y}"
      if layer.platforms[s].nil?
        layer.platforms[s] = Platform.new(self, c, @level.index, @level.width)
      else
        layer.platforms.delete(s)
      end
    end
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
    @image = Gosu::Image.new(@window, "lib/square2.png", false)
    size = (@window.width.to_f / 20.0).round
    @size = Coord.new(size, size)
    @sizeMult = Coord.new(@size.x.to_f / @image.width.to_f, @size.y.to_f / @image.height.to_f)
    @gravCounter = 0
    @coord = level.playerCoord.dup
    @vel = Coord.new(0.0, 0.0)
    @active = Coord.new(false, false)
    @touchingGround = false
    @touchingGroundCounter = 0
  end

  def jump; @vel.y = -10 if @touchingGround; end
  def vel_down; @vel.y += 0.5; @active.y = true if @vel.y.abs < 5; end
  def vel_left; @vel.x -= 0.5; @active.x = true if @vel.x.abs < 5; end
  def vel_right; @vel.x += 0.5; @active.x = true if @vel.x.abs < 5; end

  def touchingWall?; @coord.x < 0 || @coord.x > @window.width - @size.x; end

  def platformCalc(orig)
    results = []
    c2 = Coord.new(@coord.x + @size.x, @coord.y + @size.y)
    c = Coord.new(@coord.x + @size.x / 2, c2.y - @size.x / 2 - 1)
    @level.layers.each do |layer|
      layer.platforms.each_value do |platform|
        result = platform.collision(@coord, c2, c)
        results << result if result
      end
    end
    groundTouch = false
    for result in results
      if result.x != 0
        @coord.x = orig.x
        @vel.x = 0.0 if @vel.x != 0 && @vel.x / @vel.x.abs == result.x
      end
      if result.y != 0
        @coord.y = orig.y
        @vel.y = 0.0 if @vel.y != 0 && @vel.y / @vel.y.abs == result.y
        groundTouch = true if result.y == 1
      end
    end
    if groundTouch
      @touchingGroundCounter += 2 if @touchingGroundCounter < 2
    else
      @touchingGroundCounter -= 1 if @touchingGroundCounter > -2
    end
    @touchingGround = @touchingGroundCounter > 0
  end

  def gravity
    if @vel.y < 30 && @gravCounter > 1
      @gravCounter = 0
      @vel.y += 1
    end
    @gravCounter += 1
  end
  
  def update
    orig = @coord.dup
    @coord.x += @vel.x
    @coord.y += @vel.y
    @vel.x *= 0.95
    #@vel.x = 0.0 if @touchingGround && !@active.x
    gravity
    if touchingWall?
      @coord.x = orig.x
      @vel.x = 0.0
    end
    platformCalc(orig)
    @active = Coord.new(false, false)
  end

  def draw
    @image.draw @coord.x, @coord.y, Z::Player, @sizeMult.x, @sizeMult.y, $colors[@level.index]
  end
end

class Level
  attr_accessor :layers, :width, :index, :playerCoord
  def initialize(window, width = 20)
    @window = window
    @width = width
    @layers = []
    @index = 0
    @playerCoord = Coord.new(0, 0)
    @nums = [Gosu::Kb0, Gosu::Kb1, Gosu::Kb2, Gosu::Kb3, Gosu::Kb4,
             Gosu::Kb5, Gosu::Kb6, Gosu::Kb7, Gosu::Kb8, Gosu::Kb9]
  end
  def indexChange
    for i in 0...@nums.length
      num = @nums[i]
      @layers[i] = Layer.new(self) if @layers[i].nil?
      @index = i if @window.button_down?(num)
    end
  end
  def update
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
    @image = Gosu::Image.new(@window, "lib/square2.png", false)
    @size = (@window.width.to_f / width.to_f).round
    @multFactor = @size.to_f / @image.width.to_f
    @showing = false
  end
  def collision(c1, c2, c)
    return false if !@showing
    coord1 = @realCoord
    coord2 = Coord.new(@realCoord.x + @size, @realCoord.y + @size)
    x1 = c2.x > coord1.x
    y1 = c2.y > coord1.y
    x2 = coord2.x > c1.x
    y2 = coord2.y > c1.y
    bool = x1 && y1 && x2 && y2
    x = y = 0
    if bool
      coord = Coord.new(coord1.x + @size / 2, coord1.y + @size / 2)
      xdif = coord.x - c.x# + 1
      ydif = coord.y - c.y# + 1
      rx = xdif.abs > ydif.abs
      ry = xdif.abs <= ydif.abs
      rx = rx && bool
      ry = ry && bool
      x = xdif / xdif.abs if rx
      y = ydif / ydif.abs if ry
    end
    Coord.new(x, y)
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

window = Window.new
window.show