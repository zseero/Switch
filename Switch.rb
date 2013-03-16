#!/usr/bin/env ruby
#run the following to package this application:
#ocra --window --chdir-first "Switch.rb" lib/*
#--icon "SlimeWarzIcon.ico"

require_relative 'main'

class Window < Gosu::Window
  def restart
    puts "Available levels:"
    name = gets.chomp
    levelYaml = YAML.load_file('lvls/' + name + '.lvl')
    puts levelYaml
    @level = Level.new(self, name, levelYaml)
    @player = Player.new(self, @level)
  end
end

window = Window.new
window.show