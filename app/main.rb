$dragon.require 'app/lib/sprite.rb'
$dragon.require 'app/lib/particle.rb'
$dragon.require 'app/lib/emitter.rb'
require 'app/lib/ebb.rb'

$gtk.reset
$e ||= Ebb.new

GRAVITY = -0.05
ROCKET_THRUST = GRAVITY.abs * 1.2 # Relative to gravity
MAX_THRUST = ROCKET_THRUST * 1.5 # Both engines = 1.5x power not 2x power
SPINNINESS = 0.3 # How much we spin with just one rocket
SHITTINESS = 2 # Thrust/spinness can be up to this % off in either engine
STRAIN = 0.5 # How much the craft vibrates when the engines are on
FUEL_BURN_RATE = 3 # mpg
MAX_Y_VELOCITY = 1 # avoids escaping the pull of gravity
FUEL_MASS = 100 # How much fuel there is (lander gets lighter as this is burned)
CRAFT_MASS = 100 # How much the lander itself weighs without fuel
FLOOR = 30

def tick args
  $e.tick

  if args.inputs.mouse.click
    args.state.mouse_held = true
  end

  if args.inputs.mouse.up
    args.state.mouse_held = false
  end

  if (args.state.landed && args.inputs.mouse.click) || args.inputs.keyboard.key_down.space || args.state.tick_count == 0
    args.state.count ||= {}
    args.state.count[:aborts] ||= 0
    args.state.count[:goods] ||= 0
    args.state.count[:bads] ||= 0

    if args.inputs.keyboard.key_down.space && !args.state.landed
      args.state.count[:aborts] +=1
    end

    # Initial state
    args.outputs.sounds << 'sounds/sfx_sound_bling.wav'

    args.state.landed = false
    args.state.velocity_y = 0
    args.state.velocity_x = rand * 10 - 5
    args.state.sprite_y = 600
    args.state.sprite_x = 640
    args.state.rotation = rand * 10 - 5
    args.state.velocity_rotation = rand * 5 - 2
    args.state.fuel = 100
  end

  # Apply rocket thrust if keys are down or touch is down
  right_rocket_input = args.inputs.keyboard.key_held.right || (args.state.mouse_held && args.inputs.mouse.x > 640)
  left_rocket_input = args.inputs.keyboard.key_held.left || (args.state.mouse_held && args.inputs.mouse.x <= 640)

  right_rocket_thrust = right_rocket_input ? ROCKET_THRUST : 0
  left_rocket_thrust = left_rocket_input ? ROCKET_THRUST : 0

  # This lander sucks so thrust has some shittiness
  variance_left = rand * SHITTINESS
  variance_right = rand * SHITTINESS
  right_rocket_thrust += right_rocket_thrust * variance_left
  left_rocket_thrust += left_rocket_thrust * variance_right

  # Out of gas? No thrust for you
  if args.state.fuel == 0
    right_rocket_thrust = 0
    left_rocket_thrust = 0
  end

  # Almost out of gas = half thrust
  if args.state.fuel < 20
    right_rocket_thrust *= 0.5
    left_rocket_thrust *= 0.5
  end

  # Rockets can't have negative thrust
  right_rocket_thrust = [right_rocket_thrust, 0].max
  left_rocket_thrust = [left_rocket_thrust, 0].max
  # TODO: potentially ramp thrust up/down slightly
  args.state.left_thrust = left_rocket_thrust
  args.state.right_thrust = right_rocket_thrust

  # Total thrust for moving up can't be higher than MAX_THRUST
  total_thrust = [right_rocket_thrust + left_rocket_thrust, MAX_THRUST].min

  # Burn gas
  args.state.fuel -= (total_thrust * FUEL_BURN_RATE)
  args.state.fuel = [args.state.fuel, 0].max

  # a = f/m
  original_mass = CRAFT_MASS + FUEL_MASS
  current_mass = CRAFT_MASS + args.state.fuel
  mass_factor = current_mass / original_mass

  # How fast are we moving up?
  args.state.velocity_y += (args.state.rotation.vector_x * total_thrust) / mass_factor
  args.state.velocity_y = [args.state.velocity_y, MAX_Y_VELOCITY].min

  # How fast are we moving sideways?
  args.state.velocity_x += (args.state.rotation.vector_y * right_rocket_thrust) * -0.50 / mass_factor
  args.state.velocity_x += (args.state.rotation.vector_y * left_rocket_thrust) * -0.50 / mass_factor

  # How fast are we spinning?
  args.state.velocity_rotation += (right_rocket_thrust - left_rocket_thrust) * (SPINNINESS + (SPINNINESS * variance_left)) / mass_factor

  # Shake the ship and play rocket sounds
  if total_thrust > 0
    vibration = rand * (STRAIN * 2) - STRAIN
    vibration *= 2 if total_thrust == MAX_THRUST

    sound = ['sounds/sfx_damage_hit2.wav'].sample

    args.outputs.sounds << sound if args.state.tick_count % (rand(2) + 2) == 0
    args.state.rotation += vibration
  end

  # Adjust rotation
  args.state.rotation += args.state.velocity_rotation

  # Adjust height
  args.state.sprite_y += args.state.velocity_y
  args.state.sprite_x += args.state.velocity_x

  # Don't let it go below the floor
  args.state.sprite_y = [0, args.state.sprite_y].max

  # Would we be ok if we ran into the floor right now?
  safe = safe_landing?(args.state)

  # Did we land?
  explode_now = false
  if args.state.sprite_y > FLOOR
    status_text = ''
    # Not landed means gravity still pulling down
    args.state.velocity_y += GRAVITY
  elsif args.state.landed == false
    # We're below 0 and haven't recorded a landing yet
    args.state.landed = safe ? :safe : :crash
    explode_now = !safe
    args.state.count[safe ? :goods : :bads] += 1
    args.outputs.sounds << (safe ? 'sounds/sfx_sounds_fanfare3.wav' : 'sounds/sfx_exp_odd1.wav')
  elsif args.state.landed
    # We're below zero but have already landed
    args.state.velocity_y = 0;
    args.state.velocity_x = 0;
    args.state.velocity_rotation = 0;
  end


  # Beep menacingly the closer you get to the ground if you're in an unsafe condition
  args.outputs.sounds << 'sounds/sfx_sounds_Blip5.wav' if !safe && args.state.landed == false && args.state.tick_count % (args.state.sprite_y.round(0) / 20) == 0
  
  # Beep menacingly if you're low on fuel
  args.outputs.sounds << 'sounds/sfx_sounds_Blip8.wav' if args.state.fuel < 20 && args.state.landed == false && args.state.tick_count % 15 == 0

  outputs = args.outputs

  # Render labels
  # Have you done a good job or a bad job?
  if args.state.landed
    status_text = args.state.landed == :safe ? 'Good job' : 'Bad job'
    score_text = "#{args.state.count[:goods]} good / #{args.state.count[:bads]} bad / #{args.state.count[:aborts]} abort"
    status_color = args.state.landed && (args.state.landed == :safe ? [0,255,0] : [255,0,0]) || (safe ? [0,255,0] : [255,0,0])

    args.outputs.labels << [ 530, 450, score_text, 255, 255, 255 ]
    args.outputs.labels << [ 550, 420, "[space] to try again", 255, 255, 255 ]
  elsif args.state.tick_count < 60
    status_text = "Do a good job"
    status_color = [255, 255, 255]
  end
  args.outputs.labels << [ 610, 500, status_text, *status_color ]

  # Render background
  outputs.sprites << render_background(args.state)

  # Reneer ground
  outputs.sprites << [0, -100, 1280, 202, 'sprites/ground.png']

  # Render exhaust
  outputs.sprites.push *render_exhaust(args.state)

  # Render explosion
  outputs.sprites.push *render_explosion(args.state, explode_now)

  unless args.state.landed == :crash
    # Render shadow
    outputs.sprites << render_shadow(args)

    # Render ship
    outputs.sprites << render_ship(args, total_thrust, left_rocket_thrust, right_rocket_thrust, safe)
  end

  # Render HUD
  outputs.sprites.push *render_hud(args)
end

SAFE_VX = 2
SAFE_VY = 2
SAFE_ROTATION = 22
SAFE_VROTATION = 5

def safe_landing?(state)
  state.velocity_y.abs < SAFE_VX &&
  state.velocity_x.abs < SAFE_VY &&
  state.rotation.abs < SAFE_ROTATION &&
  state.velocity_rotation.abs < SAFE_VROTATION
end

def render_shadow(args)
  height = [args.state.sprite_y - FLOOR, 0].max
  shadow_scale = [(1 / (height + 1)) * 100, 1].min
  shadow_w = 80 * shadow_scale
  shadow_h = 20 * shadow_scale
  shadow_x = args.state.sprite_x + ((80 - shadow_w ) / 2)
  shadow_y = FLOOR + 10 - (shadow_h)

  a = (args.state.rotation % 360) * (-3.1415/180)
  shadow_x += Math.sin(a) * shadow_w / 1.25

  [ shadow_x.round, shadow_y.round, shadow_w.round, shadow_h.round, 'sprites/shadow.png', 0, 50 ]
end

def render_ship(args, total_thrust, left_rocket_thrust, right_rocket_thrust, safe)
  # Use a render_target so we can assemble multiple things into one logical sprite
  ship_target = args.render_target(:ship)

  # Where do we put the driver?
  driver_y = 60 - (total_thrust > 0 ? 1 : 0)
  driver_rotation = args.state.velocity_rotation * -20
  driver_rotation = 30 if driver_rotation > 30
  driver_rotation = -30 if driver_rotation < -30

  # Driver lights up green if we landed good
  driver_sat = args.state.landed == :safe && [100, 255, 100]
  driver_sat ||= safe ? [50, 50, 50] : [200, 100, 100]

  # Add the driver
  ship_target.sprites << [ 28, driver_y, 24, 24, 'sprites/driver-white.png', driver_rotation, 255, *driver_sat]

  # Which image to use for the ship?
  # TODO refactor
  lander_sprite_suffix = if left_rocket_thrust > 0 && right_rocket_thrust > 0 
    '_both_on'
  elsif left_rocket_thrust > 0
    '_left_on'
  elsif right_rocket_thrust > 0 
    '_right_on'
  else
    '_off'
  end

  # Add the ship
  ship_target.sprites << [ 0, 0, 80, 98, "sprites/lander#{lander_sprite_suffix}.png"]

  # Return the whole lander target as a sprite hash
  {
    x: args.state.sprite_x,
    y: args.state.sprite_y,
    w: 80,
    h: 98,
    path: :ship,
    source_x: 0,
    source_y: 0,
    source_w: 80,
    source_h: 98,
    angle_anchor_x: 0.5,
    angle_anchor_y: 0.0,
    angle: args.state.rotation
  }
end

def render_background(state)
  # Slowly moving background
  state.background_x ||= 0
  state.background_x_velocity ||= -2

  if state.tick_count % 100 == 0
    state.background_x_velocity = 2 if state.background_x < -1200
    state.background_x_velocity = -2 if state.background_x > -50
    state.background_x += state.background_x_velocity
  end

  # Render background
  background_gb_sat = state.fuel > 20 ? 100 : 50
  [ state.background_x, 60, 2560, 1440, 'sprites/background.png', 0, 255, background_gb_sat, background_gb_sat, background_gb_sat]
end

def render_hud(args)
  hud_target = args.render_target(:hud)

  # Will be pixel doubled
  w = 100
  h = 100

  # Corners
  c_size = 7
  c_color = [$e.wave(50,100), 255, 255, 255]
  c_path = 'sprites/reticle_corner.png'
  hud_target.sprites << [0, 0, c_size, c_size, c_path, 90, *c_color]
  hud_target.sprites << [w - c_size, 0, c_size, c_size, c_path, 180, *c_color]
  hud_target.sprites << [0, h - c_size, c_size, c_size, c_path, 0, *c_color]
  hud_target.sprites << [w - c_size, h - c_size, c_size, c_size, c_path, -90, *c_color]

  # Fuel bar
  fuel_starting_y = h - c_size - 4 - h/4
  hud_target.lines << [w - c_size, h - c_size - 4, w - c_size, fuel_starting_y, 255, 255, 255, 100]
  fuel_factor = args.state.fuel / FUEL_MASS
  fuel_color = fuel_factor < 0.2 ? [255, 0, 0, $e.blink(15) ? 255 : 50] : [255, 255, 255, 255]
  hud_target.lines << [w - c_size, fuel_starting_y, w - c_size, fuel_starting_y + ((h/4) * fuel_factor), *fuel_color]

  # Velocity center marks
  m_path = 'sprites/reticle_marker.png'
  hud_target.sprites << [0, h / 2, 1, 2, m_path, 90, *c_color]
  hud_target.sprites << [w-2, h / 2, 1, 2, m_path, 90, *c_color]
  hud_target.sprites << [w/2, h-2, 1, 2, m_path, 0, *c_color]

  # Velocity indicators
  v = $e.fps(:v, [args.state.velocity_x, args.state.velocity_y], 15)
  vx_indicator_color = v[0].abs < SAFE_VX ? [255, 255, 255, 255] : [255, 255, 0, 0]
  vy_indicator_color = v[1].abs < SAFE_VY ? [255, 255, 255, 255] : [255, 255, 0, 0]
  hud_target.sprites << [1, h/2 - v[1] * SAFE_VY * 4, 1, 2, m_path, 90, *vy_indicator_color]
  hud_target.sprites << [w-3, h/2 - v[1] * SAFE_VY * 4, 1, 2, m_path, 90, *vy_indicator_color]
  hud_target.sprites << [w/2 - v[0] * SAFE_VX * 4, h-2, 1, 2, m_path, 0, *vx_indicator_color]

  # Horizon line
  horizon_angle = $e.fps(:hud_angle_fps, args.state.rotation, 15)
  horizon_angle_velocity = $e.fps(:hud_anglev_fps, args.state.velocity_rotation, 15)
  safe_angle = (horizon_angle.abs % 360 < SAFE_ROTATION) && (horizon_angle_velocity.abs < SAFE_VROTATION)

  ## Render the HUD itself
  hud_point = $e.delay(:hud, [args.state.sprite_x, args.state.sprite_y], 10)

  # Return the whole HUD target as a sprite hash
  [{
    x: hud_point[0] - 60,
    y: hud_point[1] - 60,
    w: w * 2,
    h: h * 2,
    path: :hud,
    source_x: 0,
    source_y: 0,
    source_w: w,
    source_h: h,
    angle_anchor_x: 0.5,
    angle_anchor_y: 0.0
  }, {
    x: hud_point[0] - 102,
    y: hud_point[1] + 42,
    w: 280,
    h: 2,
    path: 'sprites/reticle_horizon.png',
    angle: horizon_angle,
    angle_anchor_x: 0.5,
    angle_anchor_y: 0.5,
    a: safe_angle ? 100 : 255,
    r: 255,
    g: safe_angle ? 255 : 0,
    b: safe_angle ? 255 : 0
  }]
end

def render_explosion(state, explode_now)
  state.explosion_emitter ||= new_explosion_emitter
  state.parts_emitters ||= (0..3).map { |i| new_parts_emitter(i) }

  state.explosion_emitter.x = state.sprite_x
  state.explosion_emitter.y = state.sprite_y
  state.explosion_emitter.on = explode_now

  state.parts_emitters.each do |emitter|
    emitter.x = state.sprite_x
    emitter.y = state.sprite_y
    emitter.on = explode_now
  end

  part_sprites = state.parts_emitters.reduce([]) { |sprites, emitter| sprites += emitter.render(state) }

  flash_sprites = []
  if explode_now
    flash_path = ['sprites/scorch_1.png', 'sprites/scorch_2.png', 'sprites/scorch_3.png'].sample
    flash_sprites = [[state.sprite_x + 40 - 160, state.sprite_y + 40 - 160, 320, 320, flash_path ]]
  end

  return state.explosion_emitter.render(state) + part_sprites + flash_sprites
end


def render_exhaust(state)
  state.left_exhaust_emitter ||= new_exhaust_emitter
  state.right_exhaust_emitter ||= new_exhaust_emitter
  state.left_spark_emitter ||= new_spark_emitter
  state.right_spark_emitter ||= new_spark_emitter

  ## Magic maths to figure out where to shoot flames from
  lx = 28
  ly = 10
  a = (state.rotation % 360) * (-3.1415/180) # to radians

  x_offset_left = (lx * Math.cos(a)) - (ly * Math.sin(a))
  x_offset_right = (lx * Math.cos(a)) - (ly * -1 * Math.sin(a))

  y_offset_left = (lx * Math.sin(a)) + (ly * Math.cos(a))
  y_offset_right = (lx * Math.sin(a)) + (ly * -1 * Math.cos(a))

  # Exhaust
  state.left_exhaust_emitter.x = state.sprite_x + 40 - x_offset_left
  state.left_exhaust_emitter.y = state.sprite_y + y_offset_left
  state.left_exhaust_emitter.rate = 1 + rand * 5
  state.left_exhaust_emitter.on = state.left_thrust > 0

  state.right_exhaust_emitter.x = state.sprite_x + 40 + x_offset_right
  state.right_exhaust_emitter.y = state.sprite_y - y_offset_right
  state.right_exhaust_emitter.rate = 1 + rand * 5
  state.right_exhaust_emitter.on = state.right_thrust > 0

  # Sparks
  state.left_spark_emitter.x = state.sprite_x + 40 - x_offset_left
  state.left_spark_emitter.y = state.sprite_y + y_offset_left
  state.left_spark_emitter.rate = rand * (state.left_thrust > 0 ? 5 : 0.05)
  state.left_spark_emitter.on = true

  state.right_spark_emitter.x = state.sprite_x + 40 + x_offset_right
  state.right_spark_emitter.y = state.sprite_y - y_offset_right
  state.right_spark_emitter.rate = rand * (state.right_thrust > 0 ? 5 : 0.05)
  state.right_spark_emitter.on = true

  return state.left_exhaust_emitter.render(state) + state.right_exhaust_emitter.render(state) + state.left_spark_emitter.render(state) + state.right_spark_emitter.render(state)
end

def new_spark_emitter
  Emitter.new.tap do |e|
    e.w = 1
    e.h = 1
    e.on = false
    e.rate = 5
    e.particle_attributes = -> (_emitter, state) {
      seed = rand

      {
        gravity: GRAVITY,
        sprite_path: -> (p) { "sprites/particle.png" },
        emission_angle: state.rotation - 90 + (rand * 30) - 15,
        emission_speed: 3 + (20 * seed),
        rotation: -> (p) { p.emission_angle - 90 },
        saturation: [255, 255, 255],
        size: -> (p) { [3, 6 * (p.emission_speed / 23)] },
        max_age: 0 + (10 * seed),
      }
    }
  end
end

def new_exhaust_emitter
  Emitter.new.tap do |e|
    e.w = 1
    e.h = 1
    e.on = false
    e.rate = 5
    e.particle_attributes = -> (_emitter, state) {
      seed = rand
      max_size = 20 + 60 * seed

      path = "sprites/particles/smoke_0#{(rand * 7.0).floor+1}.png"

      {
        gravity: GRAVITY,
        sprite_path: -> (p) { "sprites/particles/smoke_0#{(rand * 7.0).floor+1}.png" },
        emission_angle: state.rotation - 90 + (rand * 30) - 15,
        emission_speed: 5 + (5 * seed),
        saturation: -> (p) {
          ((p.max_age - p.age ) / p.max_age > (0.95 * seed)) ? [255,225,255] : [
            ((p.max_age - p.age ) / p.max_age) * 255 + (50 - (rand * 100)),
            ((p.max_age - p.age ) / p.max_age) * 100 + (20 - (rand * 40)),
            ((p.max_age - p.age ) / p.max_age) * 100 + (20 - (rand * 40))
          ]
        },
        alpha: -> (p) {
          ((p.max_age - p.age ) / p.max_age > 0.95 * seed) ? 100 : ((p.max_age - p.age) / p.max_age) * 255
        },
        rotation: -> (p) { (p.age % 360) * seed * 360},
        size: -> (p) { [(p.age/p.max_age * max_size) + (seed * 10), (p.age/p.max_age * max_size) + (seed * 10)] },
        max_age: 5 + (25 * seed)
      }
    }
  end
end

def new_parts_emitter(part_index)
  Emitter.new.tap do |e|
    e.w = 40
    e.h = 40
    e.on = false
    e.rate = 1
    e.particle_attributes = -> (_emitter, state) {
      seed = rand
      path = "sprites/particles/smoke_0#{(rand * 7.0).floor+1}.png"

      part_paths = [
        "sprites/part-capsule.png",
        "sprites/part-engine.png",
        "sprites/part-engine.png",
        "sprites/part-shield.png",
      ]

      {
        gravity: GRAVITY,
        sprite_path: part_paths[part_index],
        emission_angle: 90 + (80 - (160 * seed)),
        emission_speed: 15 + (10 * seed),
        alpha: 255,
        rotation: -> (p) { ((p.age * seed * 5) % 180) * 2 },
        size: [
          [68, 66],
          [24, 38], [24, 38],
          [68, 36]
        ][part_index],
        max_age: 200
      }
    }
  end
end


def new_explosion_emitter
  Emitter.new.tap do |e|
    e.w = 40
    e.h = 40
    e.on = false
    e.rate = 100
    e.particle_attributes = -> (_emitter, state) {
      seed = rand
      max_size = 25 + 100 * seed

      path = "sprites/particles/smoke_0#{(rand * 7.0).floor+1}.png"

      {
        gravity: GRAVITY,
        sprite_path: -> (p) { "sprites/particles/smoke_0#{(rand * 7.0).floor+1}.png" },
        emission_angle: rand * 360,
        emission_speed: 10 + (20 * seed),
        velocity: -> (p) { [p.vx + state.velocity_x * 2, p.vy + p.gravity] },
        saturation: -> (p) {
          ((p.max_age - p.age ) / p.max_age > (0.95 * seed)) ? [255,225,255] : [
            ((p.max_age - p.age ) / p.max_age) * 255 + (50 - (rand * 100)),
            ((p.max_age - p.age ) / p.max_age) * 155 + (50 - (rand * 100)),
            ((p.max_age - p.age ) / p.max_age) * 155 + (50 - (rand * 100))
          ]
        },
        alpha: -> (p) {
          ((p.max_age - p.age ) / p.max_age > 0.95 * seed) ? 100 : ((p.max_age - p.age) / p.max_age) * 255
        },
        rotation: -> (p) { (p.age % 360) * seed * 360},
        size: -> (p) { [(p.age/p.max_age * max_size) + (seed * 10), (p.age/p.max_age * max_size) + (seed * 10)] },
        max_age: 5 + (20 * seed)
      }
    }
  end
end
