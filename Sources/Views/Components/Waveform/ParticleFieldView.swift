import SwiftUI

/// Particle field visualization - floating particles react to audio energy.
/// Low frequencies push particles, high frequencies make them jitter.
struct ParticleFieldView: View {
    let audioLevel: Float
    let frequencyBands: [Float]
    let isActive: Bool
    /// Seed used for the initial particle positions/velocities. Default is
    /// random so production behavior is unchanged; tests can pass a fixed
    /// seed to make snapshots deterministic. A non-nil seed also disables
    /// per-frame jitter randomness so the rendered frame is reproducible.
    let seed: UInt64?

    init(
        audioLevel: Float,
        frequencyBands: [Float],
        isActive: Bool,
        seed: UInt64? = nil
    ) {
        self.audioLevel = audioLevel
        self.frequencyBands = frequencyBands
        self.isActive = isActive
        self.seed = seed

        // When a seed is provided, pre-populate the particles state so the
        // first rendered frame (e.g. via ImageRenderer in snapshot tests) is
        // deterministic without relying on `onAppear` having executed.
        if let seed = seed {
            let initialSize = CGSize(width: 200, height: 120)
            let initialParticles = Self.makeSeededParticles(
                count: Self.fixedParticleCount,
                in: initialSize,
                colorCount: Self.fixedColorCount,
                seed: seed
            )
            _particles = State(initialValue: initialParticles)
            _currentSize = State(initialValue: initialSize)
        }
    }

    @State private var particles: [Particle] = []
    @State private var idlePhase: CGFloat = 0
    @State private var isViewActive = false
    @State private var currentSize: CGSize = CGSize(width: 200, height: 120)

    // Static counterparts to the instance constants for use in the init,
    // where instance properties aren't yet available.
    private static let fixedParticleCount = 60
    private static let fixedColorCount = 4

    private static func makeSeededParticles(
        count: Int,
        in size: CGSize,
        colorCount: Int,
        seed: UInt64
    ) -> [Particle] {
        var rng = SeededRandomNumberGenerator(seed: seed)
        return (0..<count).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width, using: &rng),
                y: CGFloat.random(in: 0...size.height, using: &rng),
                velocityX: CGFloat.random(in: -0.5...0.5, using: &rng),
                velocityY: CGFloat.random(in: -0.5...0.5, using: &rng),
                size: CGFloat.random(in: 3...8, using: &rng),
                colorIndex: Int.random(in: 0..<colorCount, using: &rng),
                opacity: CGFloat.random(in: 0.4...0.9, using: &rng)
            )
        }
    }

    private let particleCount = 60
    private let colors: [Color] = [
        Color(red: 0.0, green: 0.9, blue: 0.95),   // Cyan
        Color(red: 0.95, green: 0.2, blue: 0.8),   // Magenta
        Color(red: 1.0, green: 0.85, blue: 0.0),   // Yellow
        Color(red: 0.4, green: 0.9, blue: 0.5),    // Green
    ]

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var velocityX: CGFloat
        var velocityY: CGFloat
        var size: CGFloat
        var colorIndex: Int
        var opacity: CGFloat
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 0.033, paused: !isViewActive)) { timeline in
                Canvas { context, size in
                    for particle in particles {
                        let rect = CGRect(
                            x: particle.x - particle.size / 2,
                            y: particle.y - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )

                        // Outer glow
                        let glowRect = rect.insetBy(dx: -4, dy: -4)
                        let glowPath = Path(ellipseIn: glowRect)
                        context.fill(
                            glowPath,
                            with: .color(colors[particle.colorIndex].opacity(particle.opacity * 0.3))
                        )

                        // Core particle
                        let particlePath = Path(ellipseIn: rect)
                        context.fill(
                            particlePath,
                            with: .color(colors[particle.colorIndex].opacity(particle.opacity))
                        )
                    }
                }
                .blur(radius: 1)
                .onChange(of: timeline.date) { _, _ in
                    updateParticles()
                }
            }
            .onAppear {
                initializeParticles(in: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                currentSize = newSize
                if particles.isEmpty {
                    initializeParticles(in: newSize)
                }
            }
        }
        .onAppear {
            isViewActive = true
        }
        .onDisappear {
            isViewActive = false
        }
    }

    private func initializeParticles(in size: CGSize) {
        currentSize = size
        if let seed = seed {
            particles = Self.makeSeededParticles(
                count: particleCount,
                in: size,
                colorCount: colors.count,
                seed: seed
            )
        } else {
            particles = (0..<particleCount).map { _ in
                Particle(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height),
                    velocityX: CGFloat.random(in: -0.5...0.5),
                    velocityY: CGFloat.random(in: -0.5...0.5),
                    size: CGFloat.random(in: 3...8),
                    colorIndex: Int.random(in: 0..<colors.count),
                    opacity: CGFloat.random(in: 0.4...0.9)
                )
            }
        }
    }

    private func updateParticles() {
        idlePhase += 0.02

        // Calculate forces from audio
        let bassForce = frequencyBands.first ?? 0 // Low frequencies push outward
        let highForce = frequencyBands.last ?? 0  // High frequencies add jitter

        for i in 0..<particles.count {
            guard i < particles.count else { break }

            var particle = particles[i]

            if isActive && audioLevel > 0.05 {
                // Audio-reactive movement

                // Use actual geometry size instead of hardcoded values
                let centerX = currentSize.width / 2
                let centerY = currentSize.height / 2
                let dx = particle.x - centerX
                let dy = particle.y - centerY
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 1 {
                    let pushStrength = CGFloat(bassForce) * 2.0
                    particle.velocityX += (dx / distance) * pushStrength
                    particle.velocityY += (dy / distance) * pushStrength
                }

                // High frequencies add jitter. When a deterministic seed is
                // supplied (test mode), skip the random jitter so subsequent
                // frames remain reproducible.
                if seed == nil {
                    let jitterStrength = CGFloat(highForce) * 3.0
                    particle.velocityX += CGFloat.random(in: -jitterStrength...jitterStrength)
                    particle.velocityY += CGFloat.random(in: -jitterStrength...jitterStrength)
                }

                // Intensity affects opacity
                particle.opacity = min(1.0, 0.5 + CGFloat(audioLevel) * 0.5)
            } else {
                // Idle gentle drift
                let drift = sin(idlePhase + CGFloat(i) * 0.1) * 0.1
                particle.velocityX += drift * 0.5
                particle.velocityY += cos(idlePhase + CGFloat(i) * 0.15) * 0.05
                particle.opacity = 0.4 + sin(idlePhase + CGFloat(i) * 0.2) * 0.2
            }

            // Apply velocity with damping
            particle.x += particle.velocityX
            particle.y += particle.velocityY
            particle.velocityX *= 0.95
            particle.velocityY *= 0.95

            // Wrap around edges using actual geometry size
            let wrapWidth = currentSize.width + 20
            let wrapHeight = currentSize.height + 20
            if particle.x < -10 { particle.x = wrapWidth - 10 }
            if particle.x > wrapWidth - 10 { particle.x = -10 }
            if particle.y < -10 { particle.y = wrapHeight - 10 }
            if particle.y > wrapHeight - 10 { particle.y = -10 }

            particles[i] = particle
        }
    }
}

#Preview("Particle Field - Active") {
    ParticleFieldView(
        audioLevel: 0.6,
        frequencyBands: [0.8, 0.6, 0.5, 0.4, 0.3, 0.25, 0.2, 0.3],
        isActive: true
    )
    .frame(width: 200, height: 120)
    .background(Color(red: 0.04, green: 0.04, blue: 0.04))
}

#Preview("Particle Field - Idle") {
    ParticleFieldView(
        audioLevel: 0,
        frequencyBands: Array(repeating: 0, count: 8),
        isActive: false
    )
    .frame(width: 200, height: 120)
    .background(Color(red: 0.04, green: 0.04, blue: 0.04))
}

// MARK: - Seeded RNG

/// Deterministic xorshift64 PRNG used to make particle-field snapshots
/// reproducible. Only used when `ParticleFieldView` is constructed with a
/// non-nil `seed`; production callers continue to use the system RNG.
fileprivate struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // xorshift requires non-zero state.
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
