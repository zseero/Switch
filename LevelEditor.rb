require_relative 'main'

puts "Existing Levels: "
names = []
Dir['lvls/*'].each do |name|
  names << name[5..-5]
end
puts names.join(' || ')
puts
printf 'Your Levelname: '
name = gets.chomp

class Window < Gosu::Window
  def initialize(name)
    super(800, 800, false)
    begin
      @level = YAML.load_file('lvls/' + name + '.lvl')
      @level.name = name
    rescue
      @level = Level.new(name) if @level.nil?
    end
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
        layer.platforms[s] = Platform.new(c, @level.index, @level.width)
      else
        layer.platforms.delete(s)
      end
    end
  end
end

class Level
  def getPlayerStart
    farDownLeft = nil
    @layers[0].platforms.each_value do |platform|
      if platform.realCoord
        if farDownLeft.nil? || (farDownLeft.x >= platform.realCoord.x &&
                                farDownLeft.y <= platform.realCoord.y)
          farDownLeft = platform.realCoord
        end
      end
    end
    if farDownLeft
      @playerCoord = Coord.new(farDownLeft.x, farDownLeft.y - $playerSize.y)
    else
      @playerCoord = Coord.new(0, 0)
    end
  end
  def save
    getPlayerStart
    #@layers.each {|layer| layer.getSides}
    file = File.open('lvls/' + @name + '.lvl', 'w')
    file.puts self.to_yaml
  end
end

class Layer
  def getSides
    @platforms.each_value do |platform|
      freeSides = []
      sides = {:left => Coord.new(-1, 0), :right => Coord.new(1, 0),
               :top => Coord.new(0, 1), :bottom => Coord.new(0, -1)}
      sides.each do |side|
        c = side[1]
        x = platform.coord.x + c.x
        y = platform.coord.y + c.y
        if !valid?(x, y) || @platforms["#{x}:#{y}"].nil?
          freeSides << side[0]
        end
      end
      platform.freeSides = freeSides
      platform.createSideQuads
    end
  end
end

window = Window.new(name)
window.show