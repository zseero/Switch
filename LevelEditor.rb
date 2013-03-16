require_relative 'main'

printf 'Levelname: '
name = gets.chomp

class Window < Gosu::Window
  def initialize(name)
    super(800, 800, false)
    @level = Level.new(self, name)
    init
  end
  def button_down(id)
    checkButtonPresses(id)
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
end

class Level
  def save
    file = File.open('lvls/' + @name + '.lvl', 'w')
    level = []
    @layers.each do |layer|
      platforms = []
      layer.platforms.each_value do |platform|
        platforms << "#{platform.coord.x}:#{platform.coord.y}"
      end
      level << platforms
    end
    file.puts level.to_yaml
  end
end

window = Window.new(name)
window.show