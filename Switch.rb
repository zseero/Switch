#!/usr/bin/env ruby
#run the following to package this application:
#ocra --windows --chdir-first "Switch.rb" lib/* dat/* lvls/*
#--icon "SlimeWarzIcon.ico"

require_relative 'main'

class Window < Gosu::Window
  attr_accessor :progress, :levelIndex
  def firstLoad
    @allLevels = Dir['lvls/*']
    progressIncrement
    @levelIndex = 0
    @progress.times {increment}
    restart
  end
  def restart
    @whiteOpacity = 15
    @level = YAML.load_file(@allLevels[@levelIndex])
    @level.index = 0
    @player = Player.new(self, @level)
  end
  def increment
    bool = @levelIndex < @progress && @levelIndex < @allLevels.length - 1
    @levelIndex += 1 if bool
    restart if bool
    bool
  end
  def decrement
    bool = @levelIndex > 0
    @levelIndex -= 1 if bool
    restart if bool
    bool
  end
  def progressIncrement
    if @progress.nil?
      begin
        file = File.open('dat/progress.dat', 'r')
        @progress = file.gets.to_i
      rescue
        @progress = 0
      end
    else
      @progress += 1
    end
    file = File.open('dat/progress.dat', 'w')
    file.puts @progress
  end
end

class Player
  def youWon
    @window.progressIncrement if @levelIndex == @progress
    @window.increment
    @window.restart
  end
end

window = Window.new
window.show