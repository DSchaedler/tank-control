# frozen_string_literal: true

def tick(args)
  $draw_queue = []

  $game ||= Game.new
  $game.tick

  args.outputs.primitives << $draw_queue
end

# Game Instance Class. Responsible for managing Game State.
class Game
  attr_accessor :ship, :star_list

  def initialize
    @ship = Ship.new(owner: :player)

    @star_list = []

    10.times do
      @star_list << EnergyPickup.new
    end
  end

  def tick
    @ship.tick
    @ship.draw

    @star_list.each do |star|
      distance_to_ship = point_distance(point1: star.location, point2: $game.ship.location)
      if distance_to_ship < 20 && $game.ship.energy < $game.ship.max_energy - 0.1
        $game.ship.energy += 0.1
        @star_list.delete star
      end
    end
    @star_list.each(&:draw)

    @star_list << EnergyPickup.new if @star_list.length < 10
  end
end

# Energy Pickup Instance
class EnergyPickup
  attr_accessor :location

  def initialize
    @location = { x: randr(0, 1280), y: randr(0, 720) }
    @sprite = 'sprites/misc/star.png'
  end

  def tick
    distance_to_ship = point_distance(point1: @location, point2: $game.ship.location)
    return unless distance_to_ship < 20

    $gtk.args.outputs.labels << { x: 100, y: 100, text: 'True' }
  end

  def draw
    $draw_queue << {
      x: @location[:x], y: @location[:y], w: 20, h: 20,
      path: @sprite
    }
  end
end

# Class Instance.
class Ship
  attr_accessor :location, :energy, :max_energy

  def initialize(owner:)
    @owner = owner
    @speed = { x: 0, y: 0 }
    @max_speed = 10
    @acceleration = 0.03
    @left_foward_ctrl = :q
    @sprite = 'sprites/misc/lowrez-ship-blue.png'
    @location = { x: 1280 / 2, y: 720 / 2 }
    @rotation = 0
    @energy = 0.5
    @max_energy = 1
    @min_energy = 0
  end

  def tick
    movement
  end

  def movement
    inputs

    @speed[:x] = @max_speed if @speed[:x] > @max_speed
    @speed[:y] = @max_speed if @speed[:y] > @max_speed
    @speed[:x] = @max_speed * -1 if @speed[:x] < @max_speed * -1
    @speed[:y] = @max_speed * -1 if @speed[:y] < @max_speed * -1

    @location = { x: @location[:x] + @speed[:x], y: @location[:y] + @speed[:y] }
    screen_wrap
  end

  def screen_wrap
    @location[:x] = 0 if @location[:x] > 1280
    @location[:x] = 1280 if (@location[:x]).negative?

    @location[:y] = 0 if @location[:y] > 720
    @location[:y] = 720 if (@location[:y]).negative?
  end

  def inputs
    dh_keys = $gtk.args.inputs.keyboard.keys[:down_or_held]
    accel_vector = point_at_distance_angle(point: { x: 0, y: 0 }, distance: @acceleration, angle: @rotation)

    @rotation += 2 if dh_keys.include? :a
    @rotation -= 2 if dh_keys.include? :d

    use_fuel = false

    accel_vector = { x: accel_vector[:x] * -1, y: accel_vector[:y] * -1 } if dh_keys.include? :s

    if dh_keys.include?(:w) || dh_keys.include?(:s)
      new_speed_x = @speed[:x] + accel_vector[:x]
      if new_speed_x >= @max_speed * -1 && new_speed_x <= @max_speed && @energy > @acceleration / 200
        @speed[:x] = new_speed_x
        use_fuel = true
      end
      new_speed_y = @speed[:y] + accel_vector[:y]
      if new_speed_y >= @max_speed * -1 && new_speed_y <= @max_speed && @energy > @acceleration / 200
        @speed[:y] = new_speed_y
        use_fuel = true
      end
      @energy -= @acceleration / 100 if use_fuel
    end

    return unless dh_keys.include? :q

    @speed[:x] -= @acceleration * 2 if @speed[:x] > @acceleration * 2
    @speed[:x] += @acceleration * 2 if @speed[:x] < 0 - (@acceleration * 2)
    @speed[:x] = 0 if @speed[:x] > 0 - (@acceleration * 2) && @speed[:x] < @acceleration * 2

    @speed[:y] -= @acceleration * 2 if @speed[:y] > @acceleration * 2
    @speed[:y] += @acceleration * 2 if @speed[:y] < 0 - (@acceleration * 2)
    @speed[:y] = 0 if @speed[:y] > 0 - (@acceleration * 2) && @speed[:y] < @acceleration * 2
  end

  def draw
    $draw_queue << {
      x: @location[:x], y: @location[:y], w: 20, h: 20,
      path: @sprite,
      angle: @rotation - 90
    }

    draw_bar
  end

  def draw_bar
    box = { x: 20, y: 20, w: 400, h: 30 }
    bar_margin = 3
    border_color = { r: 0, g: 0, b: 0, a: 255 }
    fill_color = { r: 0, g: 0, b: 255, a: 128 }

    fill_box = { x: box[:x] + bar_margin, y: box[:y] + bar_margin, w: (box[:w] - (bar_margin * 2)) * @energy, h: box[:h] - (bar_margin * 2) }

    $draw_queue << box.merge(border_color).merge(primitive_marker: :border)
    $draw_queue << fill_box.merge(fill_color).merge(primitive_marker: :solid)
  end
end

# Calculates a new `point` given a starting `point`, distance, and angle.
# @return [Hash] `point` in DR hash notation.
def point_at_distance_angle(options = {})
  point = options[:point]
  distance = options[:distance]
  angle = options[:angle]

  new_point = {}

  new_point[:x] = (distance * Math.cos(angle * Math::PI / 180)) + point[:x]
  new_point[:y] = (distance * Math.sin(angle * Math::PI / 180)) + point[:y]
  new_point
end

# Calculates the difference between two points
# @return [Array] An array with the x difference as `[0]` and the y distance as `[1]`
def point_difference(point1:, point2:)
  [point1.x - point2.x, point1.y - point2.y]
end

# Calculates the distance between two points
# @return [Float]
def point_distance(point1:, point2:)
  dx = point2.x - point1.x
  dy = point2.y - point1.y
  Math.sqrt((dx * dx) + (dy * dy))
end

def randr(min, max)
  rand(max - min + 1) + min
end
