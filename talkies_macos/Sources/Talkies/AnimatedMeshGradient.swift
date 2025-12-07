import SwiftUI

struct AnimatedMeshGradient: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Create organic, flowing caustics-like pattern
                let colors: [Color] = [
                    Color(red: 0.1, green: 0.2, blue: 0.6),
                    Color(red: 0.3, green: 0.1, blue: 0.7),
                    Color(red: 0.5, green: 0.0, blue: 0.8),
                    Color(red: 0.1, green: 0.4, blue: 0.9),
                    Color(red: 0.2, green: 0.1, blue: 0.5)
                ]

                // Create multiple flowing blobs for caustics effect
                for i in 0..<5 {
                    let offset = Double(i) * 0.4
                    let x = size.width * 0.5 + cos(time * 0.3 + offset) * size.width * 0.3
                    let y = size.height * 0.5 + sin(time * 0.4 + offset) * size.height * 0.3
                    let radius = size.width * (0.3 + sin(time * 0.5 + offset) * 0.1)

                    let gradient = Gradient(colors: [
                        colors[i].opacity(0.6),
                        colors[i].opacity(0.3),
                        colors[i].opacity(0.0)
                    ])

                    let radialGradient = GraphicsContext.Shading.radialGradient(
                        gradient,
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: radius
                    )

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: radialGradient
                    )
                }
            }
        }
    }
}
