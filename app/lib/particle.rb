class Particle < Sprite
  attr_accessor :emission_speed, :size, :vx, :vy, :velocity, :heading, :emission_angle, :age, :max_age, :alpha, :gravity, :saturation, :sprite_path

  def show?
    @age <= @max_age
  end
  
  def tick
    @age += 1

    # Update the path if needed
    @path = @sprite_path.call(self) if @sprite_path.respond_to?(:call)

    # Dimensions
    @w, @h = @size.respond_to?(:call) ? @size.call(self) : @size

    # Calculate new velocity, store
    @vx, @vy = @velocity.call(self)

    # Saturation
    @r, @g, @b = @saturation.respond_to?(:call) ? @saturation.call(self) : @saturation

    # Calculate new logical position, store
    @x, @y = @position
    @x += @vx
    @y += @vy

    @y = [@y, 30].max
    @position = [@x, @y]

    @angle = @rotation.respond_to?(:call) ? @rotation.call(self) : @rotation

    @w, @h = @size.respond_to?(:call) ? @size.call(self) : @size

    # Offset by size to keep particle centered
    @x -= @w/2
    @y -= @h/2

    @a = @alpha.respond_to?(:call) ? @alpha.call(self) : @alpha
  end

  def initialize(
      position: [0,0],
      size: [4,4],
      emission_speed: 1,
      emission_angle: rand * 360,
      rotation: -> (p) { p.age % 360 },
      velocity: -> (p) { [p.vx, p.vy + p.gravity] },
      max_age: 100,
      alpha: -> (p) { ((p.max_age - p.age) / p.max_age) * 255 },
      gravity: 0,
      sprite_path: 'sprites/particle.png',
      saturation: -> (p) { [255,255,255] }
    )
    @position = position
    @size = size
    @emission_speed = emission_speed
    @emission_angle = emission_angle

    @vx, @vy = [@emission_angle.vector_x * @emission_speed, @emission_angle.vector_y * @emission_speed]

    @age = 0
    @max_age = max_age

    @gravity = gravity

    @alpha = alpha

    @rotation = rotation
    @velocity = velocity

    @sprite_path = sprite_path
    @path = sprite_path
    @saturation = saturation
  end
end
