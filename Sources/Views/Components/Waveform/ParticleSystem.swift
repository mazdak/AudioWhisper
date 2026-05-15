import SwiftUI

/// A particle that floats upward and fades out.
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var opacity: Double
    var size: CGFloat
    var color: Color
    var rotation: Double
    var lifetime: Double
}

/// Particle emitter view that spawns particles based on audio level.
struct ParticleEmitterView: View {
    let audioLevel: Float
    let isActive: Bool
    let bounds: CGSize

    // Colors for particles (sourced from ParticlePalette)
    private let particleColors: [Color] = ParticlePalette.defaults

    @State private var particles: [Particle] = []
    @State private var lastSpawnTime: Date = Date()

    private let maxParticles = 50
    private let spawnThreshold: Float = 0.3

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, _ in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.position.x - particle.size / 2,
                        y: particle.position.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )

                    context.opacity = particle.opacity
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(particle.color)
                    )

                    // Add glow
                    context.opacity = particle.opacity * 0.3
                    let glowRect = rect.insetBy(dx: -particle.size * 0.5, dy: -particle.size * 0.5)
                    context.fill(
                        Circle().path(in: glowRect),
                        with: .color(particle.color)
                    )
                }
            }
            .onChange(of: timeline.date) { _, _ in
                updateParticles()
                maybeSpawnParticles()
            }
        }
    }

    private func updateParticles() {
        let deltaTime: Double = 0.016 // ~60fps

        particles = particles.compactMap { particle in
            var p = particle

            // Update position
            p.position.x += p.velocity.x * deltaTime
            p.position.y += p.velocity.y * deltaTime

            // Apply gravity (slight upward drift)
            p.velocity.y -= 50 * deltaTime

            // Reduce lifetime and opacity
            p.lifetime -= deltaTime
            p.opacity = max(0, p.lifetime / 2.0) // Fade over 2 seconds

            // Shrink slightly
            p.size = max(1, p.size - 0.1)

            // Remove dead particles
            guard p.lifetime > 0 && p.opacity > 0.01 else { return nil }
            guard p.position.y > -50 && p.position.y < bounds.height + 50 else { return nil }
            guard p.position.x > -50 && p.position.x < bounds.width + 50 else { return nil }

            return p
        }
    }

    private func maybeSpawnParticles() {
        guard isActive && audioLevel > spawnThreshold else { return }
        guard particles.count < maxParticles else { return }

        // Spawn rate based on audio level
        let now = Date()
        let timeSinceLastSpawn = now.timeIntervalSince(lastSpawnTime)
        let spawnInterval = 0.1 / Double(audioLevel)

        guard timeSinceLastSpawn > spawnInterval else { return }
        lastSpawnTime = now

        // Spawn 1-3 particles based on level
        let spawnCount = Int(audioLevel * 3)
        for _ in 0..<spawnCount {
            spawnParticle()
        }
    }

    private func spawnParticle() {
        let color = particleColors.randomElement() ?? .cyan
        let size = CGFloat.random(in: 3...8) * CGFloat(audioLevel + 0.5)

        let particle = Particle(
            position: CGPoint(
                x: CGFloat.random(in: 0...bounds.width),
                y: bounds.height * 0.5 + CGFloat.random(in: -20...20)
            ),
            velocity: CGPoint(
                x: CGFloat.random(in: -30...30),
                y: CGFloat.random(in: (-80)...(-40)) * CGFloat(audioLevel + 0.5)
            ),
            opacity: Double.random(in: 0.6...1.0),
            size: size,
            color: color,
            rotation: Double.random(in: 0...360),
            lifetime: Double.random(in: 1.5...2.5)
        )

        particles.append(particle)
    }
}

/// Wrapper view that provides bounds to the particle emitter.
struct ParticleOverlay: View {
    let audioLevel: Float
    let isActive: Bool

    var body: some View {
        GeometryReader { geometry in
            ParticleEmitterView(
                audioLevel: audioLevel,
                isActive: isActive,
                bounds: geometry.size
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Particles") {
    ZStack {
        Color(red: 0.02, green: 0.02, blue: 0.04)

        ParticleOverlay(audioLevel: 0.7, isActive: true)
    }
    .frame(width: 280, height: 200)
}
