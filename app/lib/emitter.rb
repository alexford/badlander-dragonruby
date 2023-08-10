class Emitter
  MAX_PARTICLES = 5000

  attr_accessor :x, :y, :w, :h, :gravity, :on, :rate, :particle_attributes

  def render(state)
    if @on && @particles.length < MAX_PARTICLES
      emit(state)
    end

    @particles.select! { |p| p.show? }
    @particles.each { |p| p.tick }
  end

  def initialize
    @particles = []
    @particle_attributes = {}
  end

  private

  def emit(state)
    @rate ||= 1
    
    if @rate >= 1
      new_particles = @rate
    else
      new_particles = state.tick_count % (1.0 / @rate).round == 0 ? 1 : 0
    end
 
    new_particles.map do
      local_x = rand * @w
      local_y = rand * @h

      attributes = (@particle_attributes.respond_to?(:call) ?
        @particle_attributes.call(self, state) : @particle_attributes).merge(
          position: [@x + local_x, @y + local_y]
        )

      @particles << Particle.new(attributes)
    end
  end
end
