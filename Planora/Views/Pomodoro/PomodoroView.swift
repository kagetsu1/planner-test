import SwiftUI
import Foundation

struct PomodoroView: View {
    @State private var timeRemaining: TimeInterval = 25 * 60 // 25 minutes
    @State private var isActive = false
    @State private var isBreak = false
    @State private var completedSessions = 0
    @State private var showingSettings = false
    
    @AppStorage("focusDuration") private var focusDuration: Int = 25
    @AppStorage("breakDuration") private var breakDuration: Int = 5
    @AppStorage("longBreakDuration") private var longBreakDuration: Int = 15
    @AppStorage("sessionsBeforeLongBreak") private var sessionsBeforeLongBreak: Int = 4
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Timer Display
                timerDisplay
                
                // Progress Ring
                progressRing
                
                // Controls
                controls
                
                // Session Info
                sessionInfo
                
                Spacer()
            }
            .padding()
            .navigationTitle("Pomodoro Timer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                PomodoroSettingsView()
            }
            .onReceive(timer) { _ in
                if isActive && timeRemaining > 0 {
                    timeRemaining -= 1
                } else if timeRemaining == 0 {
                    timerCompleted()
                }
            }
        }
    }
    
    // MARK: - Timer Display
    private var timerDisplay: some View {
        VStack(spacing: 8) {
            Text(isBreak ? "Break Time" : "Focus Time")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(isBreak ? .green : .blue)
            
            Text(timeString)
                .font(.system(size: 60, weight: .thin, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Progress Ring
    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)
                .frame(width: 200, height: 200)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [isBreak ? .green : .blue, isBreak ? .green.opacity(0.5) : .blue.opacity(0.5)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
    
    // MARK: - Controls
    private var controls: some View {
        HStack(spacing: 30) {
            // Reset Button
            Button(action: resetTimer) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(CircleButtonStyle())
            
            // Start/Pause Button
            Button(action: toggleTimer) {
                Image(systemName: isActive ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .buttonStyle(CircleButtonStyle(backgroundColor: isActive ? .orange : .blue))
            
            // Skip Button
            Button(action: skipTimer) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(CircleButtonStyle())
        }
    }
    
    // MARK: - Session Info
    private var sessionInfo: some View {
        VStack(spacing: 16) {
            HStack {
                VStack {
                    Text("\(completedSessions)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(completedSessions * focusDuration)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Next Break Info
            if !isBreak {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.orange)
                    
                    Text("Next break in \(sessionsBeforeLongBreak - (completedSessions % sessionsBeforeLongBreak)) sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var progress: Double {
        let totalTime: TimeInterval = isBreak ? TimeInterval(breakDuration * 60) : TimeInterval(focusDuration * 60)
        return 1 - (timeRemaining / totalTime)
    }
    
    // MARK: - Helper Methods
    private func toggleTimer() {
        isActive.toggle()
    }
    
    private func resetTimer() {
        isActive = false
        timeRemaining = isBreak ? TimeInterval(breakDuration * 60) : TimeInterval(focusDuration * 60)
    }
    
    private func skipTimer() {
        timerCompleted()
    }
    
    private func timerCompleted() {
        isActive = false
        
        if isBreak {
            // Break completed, start focus session
            isBreak = false
            timeRemaining = TimeInterval(focusDuration * 60)
        } else {
            // Focus session completed
            completedSessions += 1
            
            // Check if it's time for a long break
            if completedSessions % sessionsBeforeLongBreak == 0 {
                timeRemaining = TimeInterval(longBreakDuration * 60)
            } else {
                timeRemaining = TimeInterval(breakDuration * 60)
            }
            
            isBreak = true
        }
        
        // Trigger haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Circle Button Style
struct CircleButtonStyle: SwiftUI.ButtonStyle {
    let backgroundColor: Color
    
    init(backgroundColor: Color = Color(.systemGray5)) {
        self.backgroundColor = backgroundColor
    }
    
    func makeBody(configuration: SwiftUI.ButtonStyleConfiguration) -> some View {
        configuration.label
            .frame(width: 60, height: 60)
            .background(backgroundColor)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Pomodoro Settings View
struct PomodoroSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("focusDuration") private var focusDuration: Int = 25
    @AppStorage("breakDuration") private var breakDuration: Int = 5
    @AppStorage("longBreakDuration") private var longBreakDuration: Int = 15
    @AppStorage("sessionsBeforeLongBreak") private var sessionsBeforeLongBreak: Int = 4
    
    var body: some View {
        NavigationView {
            Form {
                Section("Focus Session") {
                    Stepper("Duration: \(focusDuration) minutes", value: $focusDuration, in: 1...60)
                }
                
                Section("Short Break") {
                    Stepper("Duration: \(breakDuration) minutes", value: $breakDuration, in: 1...30)
                }
                
                Section("Long Break") {
                    Stepper("Duration: \(longBreakDuration) minutes", value: $longBreakDuration, in: 5...60)
                }
                
                Section("Sessions Before Long Break") {
                    Stepper("Sessions: \(sessionsBeforeLongBreak)", value: $sessionsBeforeLongBreak, in: 2...8)
                }
            }
            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct PomodoroView_Previews: PreviewProvider {
    static var previews: some View {
        PomodoroView()
    }
}
