import Foundation
import SwiftUI

@Observable
class PomodoroTimer {
    var isRunning = false
    var timeRemaining: TimeInterval = 25 * 60 // 25 minutes in seconds
    var taskTitle: String = ""
    
    private var timer: Timer?
    private let defaultDuration: TimeInterval = 25 * 60 // 25 minutes
    
    func start(for taskTitle: String) {
        self.taskTitle = taskTitle
        // Only reset time if it's a fresh start (time is at default or 0)
        if timeRemaining == defaultDuration || timeRemaining == 0 {
            self.timeRemaining = defaultDuration
        }
        self.isRunning = true
        
        // Invalidate any existing timer first
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.stop()
                // Play completion sound/haptic
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    func reset() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        timeRemaining = defaultDuration
    }
    
    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        return 1.0 - (timeRemaining / defaultDuration)
    }
}

