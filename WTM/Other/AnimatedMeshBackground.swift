//
//  AnimatedMeshBackground.swift
//  WTM
//

import SwiftUI

struct AnimatedMeshBackground: View {
    let accentColor: Color
    let secondaryAccentColor: Color

    @State private var phase: CGFloat = 0

    init(
        accentColor: Color = .cyan,
        secondaryAccentColor: Color = .mint
    ) {
        self.accentColor = accentColor
        self.secondaryAccentColor = secondaryAccentColor
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                blob(
                    colors: [accentColor.opacity(0.95), secondaryAccentColor.opacity(0.7)],
                    size: geo.size.width * 1.1,
                    center: CGPoint(x: geo.size.width * 0.2, y: geo.size.height * 0.25),
                    phase: phase,
                    xRange: geo.size.width * 0.12,
                    yRange: geo.size.height * 0.18,
                    speed: 0.9
                )

                blob(
                    colors: [accentColor.opacity(0.9), Color.orange.opacity(0.7)],
                    size: geo.size.width * 0.95,
                    center: CGPoint(x: geo.size.width * 0.85, y: geo.size.height * 0.2),
                    phase: phase,
                    xRange: geo.size.width * 0.14,
                    yRange: geo.size.height * 0.12,
                    speed: 1.1
                )

                blob(
                    colors: [secondaryAccentColor.opacity(0.9), Color.indigo.opacity(0.7)],
                    size: geo.size.width * 1.25,
                    center: CGPoint(x: geo.size.width * 0.7, y: geo.size.height * 0.85),
                    phase: phase,
                    xRange: geo.size.width * 0.16,
                    yRange: geo.size.height * 0.14,
                    speed: 0.8
                )

                blob(
                    colors: [accentColor.opacity(0.9), Color.teal.opacity(0.6)],
                    size: geo.size.width * 0.9,
                    center: CGPoint(x: geo.size.width * 0.15, y: geo.size.height * 0.8),
                    phase: phase,
                    xRange: geo.size.width * 0.1,
                    yRange: geo.size.height * 0.16,
                    speed: 1.25
                )
            }
            .blur(radius: 45)
            .saturation(1.2)
            .hueRotation(.degrees(Double(phase) * 360))
            .onAppear {
                withAnimation(.linear(duration: 26).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .ignoresSafeArea()
    }

    private func blob(
        colors: [Color],
        size: CGFloat,
        center: CGPoint,
        phase: CGFloat,
        xRange: CGFloat,
        yRange: CGFloat,
        speed: CGFloat
    ) -> some View {
        let angle = phase * 2 * .pi * speed
        let x = center.x + xRange * sin(angle)
        let y = center.y + yRange * cos(angle * 0.92)

        return Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: colors),
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.55
                )
            )
            .frame(width: size, height: size)
            .position(x: x, y: y)
            .blendMode(.screen)
    }
}
