import SwiftUI

struct PomodoroTimerView: View {
    @Bindable var timer: PomodoroTimer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { proxy in
            let ringDiameter = min(280, min(proxy.size.width, proxy.size.height) * 0.42)

            VStack(spacing: 18) {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .accessibilityLabel("Close Pomodoro")

                    Spacer()

                    // Focus visual
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.system(size: 14, weight: .bold))
                        Text("Focus mode")
                            .anchorFont(.caption, weight: .semibold)
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.white.opacity(0.14))
                    )
                    .accessibilityElement(children: .combine)

                    Spacer()

                    // Spacer to keep the pill centered relative to the close button
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.top, 10)

                // Task Title
                Text(timer.taskTitle)
                    .anchorFont(.title, weight: .bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)

                // Timer Display
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 12)
                        .frame(width: ringDiameter, height: ringDiameter)

                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(
                            Color.anchorCoral,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: ringDiameter, height: ringDiameter)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timer.progress)

                    VStack(spacing: 4) {
                        Text(timer.formattedTime)
                            .anchorFont(.largeTitle, weight: .bold)
                            .foregroundStyle(.white)

                        Text(timer.isRunning ? "Focus" : "Paused")
                            .anchorFont(.caption, weight: .medium)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(.vertical, 10)

                // Control Buttons
                HStack(spacing: 14) {
                    if timer.isRunning {
                        Button {
                            timer.pause()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.18))
                                .foregroundStyle(.white)
                                .cornerRadius(14)
                        }
                    } else {
                        Button {
                            timer.start(for: timer.taskTitle)
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.anchorCoral)
                                .foregroundStyle(.white)
                                .cornerRadius(14)
                        }
                    }

                    Button {
                        timer.reset()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.18))
                            .foregroundStyle(.white)
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color.anchorCoral.opacity(0.85), Color.anchorCoral.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.0)
                        ],
                        center: .top,
                        startRadius: 10,
                        endRadius: min(proxy.size.width, proxy.size.height) * 0.75
                    )
                }
                .ignoresSafeArea()
            )
        }
    }
}

