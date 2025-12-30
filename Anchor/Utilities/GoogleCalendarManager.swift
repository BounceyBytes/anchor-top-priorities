import Foundation
import SwiftUI
import GoogleSignIn

@Observable
class GoogleCalendarManager {
    // MARK: - CONFIGURATION
    // TODO: USER MUST UPDATE THIS
    // 
    // IMPORTANT: After updating the clientID below, you MUST also update the URL scheme in Info.plist
    // The URL scheme should be the reversed client ID.
    // Example: If clientID is "123456789-abc.apps.googleusercontent.com"
    //          Then URL scheme in Info.plist should be "com.googleusercontent.apps.123456789-abc"
    private let clientID = "485267448887-lbv2as73km55nh4pshqouo54fusaufel.apps.googleusercontent.com"
    private let kCalendarScope = "https://www.googleapis.com/auth/calendar.events"
    
    var isSignedIn: Bool = false
    var currentUser: GIDGoogleUser?
    
    init() {
        // Configure Google Sign-In with client ID
        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration
        
        // Restore previous session
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            guard let self else { return }
            let applyState = {
                if let user = user {
                    self.isSignedIn = true
                    self.currentUser = user
                } else {
                    self.isSignedIn = false
                    self.currentUser = nil
                }
            }
            
            if Thread.isMainThread {
                applyState()
            } else {
                DispatchQueue.main.async(execute: applyState)
            }
        }
    }
    
    func signIn(rootViewController: UIViewController) {
        let configuration = GIDConfiguration(clientID: clientID)
        
        GIDSignIn.sharedInstance.configuration = configuration
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController, hint: nil, additionalScopes: [kCalendarScope]) { [weak self] result, error in
            guard let self = self, let result = result, error == nil else {
                print("Sign in failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let applyState = {
                self.isSignedIn = true
                self.currentUser = result.user
            }
            
            if Thread.isMainThread {
                applyState()
            } else {
                DispatchQueue.main.async(execute: applyState)
            }
        }
    }
    
    func signOut() {
        // Ensure we're on the main thread for UI-related operations
        // Button handlers in SwiftUI are already on main thread, but this is defensive
        if Thread.isMainThread {
            performSignOut()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performSignOut()
            }
        }
    }
    
    private func performSignOut() {
        // Sign out from Google Sign-In
        GIDSignIn.sharedInstance.signOut()
        
        // Update state
        self.isSignedIn = false
        self.currentUser = nil
    }
    
    // MARK: - Token + REST Helpers
    
    private enum CalendarError: LocalizedError {
        case notSignedIn
        case tokenUnavailable
        case invalidResponse
        case httpError(status: Int, message: String?)
        
        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Not signed in to Google."
            case .tokenUnavailable:
                return "Could not get a valid Google access token."
            case .invalidResponse:
                return "Invalid response from Google Calendar."
            case .httpError(let status, let message):
                if let message, !message.isEmpty {
                    return "Google Calendar error (\(status)): \(message)"
                }
                return "Google Calendar error (\(status))."
            }
        }
    }
    
    private struct CalendarAPIErrorBody: Decodable {
        struct ErrorInfo: Decodable {
            let message: String?
        }
        let error: ErrorInfo?
    }
    
    private struct CalendarEventInsertResponse: Decodable {
        let id: String?
    }
    
    private struct CalendarEventsListResponse: Decodable {
        struct Event: Decodable {
            struct EventDateTime: Decodable {
                let dateTime: String?
                let date: String?
            }
            let id: String?
            let summary: String?
            let start: EventDateTime?
            let end: EventDateTime?
        }
        let items: [Event]?
    }

    struct DayEvent: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
    }
    
    private func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    private func withFreshAccessToken(_ completion: @escaping (Result<String, Error>) -> Void) {
        guard let user = currentUser ?? GIDSignIn.sharedInstance.currentUser else {
            completion(.failure(CalendarError.notSignedIn))
            return
        }
        
        // Keep local state in sync with SDK state (on main for SwiftUI friendliness).
        let applyState = {
            self.currentUser = user
            self.isSignedIn = true
        }
        if Thread.isMainThread {
            applyState()
        } else {
            DispatchQueue.main.async(execute: applyState)
        }
        
        user.refreshTokensIfNeeded { refreshedUser, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let refreshedUser, let token = refreshedUser.accessToken.tokenString as String? else {
                completion(.failure(CalendarError.tokenUnavailable))
                return
            }
            completion(.success(token))
        }
    }
    
    private func calendarRequest(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        jsonBody: [String: Any]? = nil,
        completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void
    ) {
        withFreshAccessToken { tokenResult in
            switch tokenResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let token):
                var components = URLComponents()
                components.scheme = "https"
                components.host = "www.googleapis.com"
                components.path = path
                components.queryItems = queryItems.isEmpty ? nil : queryItems
                
                guard let url = components.url else {
                    completion(.failure(CalendarError.invalidResponse))
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = method
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                
                if let jsonBody {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try? JSONSerialization.data(withJSONObject: jsonBody, options: [])
                }
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error {
                        completion(.failure(error))
                        return
                    }
                    guard let http = response as? HTTPURLResponse, let data else {
                        completion(.failure(CalendarError.invalidResponse))
                        return
                    }
                    
                    if (200..<300).contains(http.statusCode) {
                        completion(.success((data, http)))
                        return
                    }
                    
                    // Try to decode a Google API error message.
                    let message: String? = {
                        if let body = try? JSONDecoder().decode(CalendarAPIErrorBody.self, from: data) {
                            return body.error?.message
                        }
                        return nil
                    }()
                    
                    completion(.failure(CalendarError.httpError(status: http.statusCode, message: message)))
                }.resume()
            }
        }
    }
    
    // MARK: - Calendar Operations
    
    func scheduleEvent(title: String, startTime: Date, durationMinutes: Int = 60, completion: @escaping (Result<String, Error>) -> Void) {
        let startISO = iso8601String(startTime)
        let endISO = iso8601String(startTime.addingTimeInterval(TimeInterval(durationMinutes * 60)))
        
        let body: [String: Any] = [
            "summary": title,
            "description": "Scheduled via Anchor App",
            "start": [
                "dateTime": startISO,
                "timeZone": TimeZone.current.identifier
            ],
            "end": [
                "dateTime": endISO,
                "timeZone": TimeZone.current.identifier
            ]
        ]
        
        calendarRequest(
            method: "POST",
            path: "/calendar/v3/calendars/primary/events",
            jsonBody: body
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let (data, _)):
                do {
                    let decoded = try JSONDecoder().decode(CalendarEventInsertResponse.self, from: data)
                    if let id = decoded.id {
                        completion(.success(id))
                    } else {
                        completion(.failure(CalendarError.invalidResponse))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchAvailableTimeSlots(for date: Date, durationMinutes: Int = 60, completion: @escaping (Result<[Date], Error>) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let timeMin = iso8601String(startOfDay)
        let timeMax = iso8601String(endOfDay)
        
        calendarRequest(
            method: "GET",
            path: "/calendar/v3/calendars/primary/events",
            queryItems: [
                URLQueryItem(name: "timeMin", value: timeMin),
                URLQueryItem(name: "timeMax", value: timeMax),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime")
            ]
        ) { result in
            if case .failure(let error) = result {
                completion(.failure(error))
                return
            }
            
            guard case .success(let (data, _)) = result else {
                completion(.failure(CalendarError.invalidResponse))
                return
            }
            
            // Get all busy periods
            var busyPeriods: [(start: Date, end: Date)] = []
            
            do {
                let decoded = try JSONDecoder().decode(CalendarEventsListResponse.self, from: data)
                let items = decoded.items ?? []
                
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let dateOnly = DateFormatter()
                dateOnly.calendar = calendar
                dateOnly.locale = Locale(identifier: "en_US_POSIX")
                dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
                dateOnly.dateFormat = "yyyy-MM-dd"
                
                for event in items {
                    guard let startObj = event.start, let endObj = event.end else { continue }
                    
                    func parseEventTime(_ obj: CalendarEventsListResponse.Event.EventDateTime) -> Date? {
                        if let dt = obj.dateTime, let d = iso.date(from: dt) {
                            return d
                        }
                        if let d = obj.date, let dateVal = dateOnly.date(from: d) {
                            return dateVal
                        }
                        return nil
                    }
                    
                    if let start = parseEventTime(startObj), let end = parseEventTime(endObj) {
                        busyPeriods.append((start: start, end: end))
                    }
                }
            } catch {
                completion(.failure(error))
                return
            }
            
            // Sort busy periods by start time
            busyPeriods.sort { $0.start < $1.start }
            
            // Find available slots (gaps between busy periods or at start/end of day)
            var availableSlots: [Date] = []
            let now = Date()
            let workStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? startOfDay
            let workEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: date) ?? endOfDay
            
            // Start from now or work start, whichever is later
            var currentTime = max(now, workStart)
            
            // If no events, suggest times throughout the day
            if busyPeriods.isEmpty {
                var slot = currentTime
                while slot < workEnd {
                    let slotEnd = slot.addingTimeInterval(TimeInterval(durationMinutes * 60))
                    if slotEnd <= workEnd {
                        availableSlots.append(slot)
                        slot = slot.addingTimeInterval(TimeInterval(durationMinutes * 60))
                    } else {
                        break
                    }
                }
            } else {
                // Check gap before first event
                if let firstBusy = busyPeriods.first {
                    let gap = firstBusy.start.timeIntervalSince(currentTime)
                    if gap >= TimeInterval(durationMinutes * 60) {
                        availableSlots.append(currentTime)
                    }
                }
                
                // Check gaps between events
                for i in 0..<busyPeriods.count - 1 {
                    let gapStart = busyPeriods[i].end
                    let gapEnd = busyPeriods[i + 1].start
                    let gap = gapEnd.timeIntervalSince(gapStart)
                    
                    if gap >= TimeInterval(durationMinutes * 60) {
                        availableSlots.append(gapStart)
                    }
                }
                
                // Check gap after last event
                if let lastBusy = busyPeriods.last {
                    let gapStart = lastBusy.end
                    let gap = workEnd.timeIntervalSince(gapStart)
                    
                    if gap >= TimeInterval(durationMinutes * 60) {
                        availableSlots.append(gapStart)
                    }
                }
            }
            
            // Return up to 3 suggested times
            let suggestedSlots = Array(availableSlots.prefix(3))
            completion(.success(suggestedSlots))
        }
    }

    func fetchDayEvents(for date: Date, completion: @escaping (Result<[DayEvent], Error>) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let timeMin = iso8601String(startOfDay)
        let timeMax = iso8601String(endOfDay)

        calendarRequest(
            method: "GET",
            path: "/calendar/v3/calendars/primary/events",
            queryItems: [
                URLQueryItem(name: "timeMin", value: timeMin),
                URLQueryItem(name: "timeMax", value: timeMax),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime")
            ]
        ) { result in
            if case .failure(let error) = result {
                completion(.failure(error))
                return
            }

            guard case .success(let (data, _)) = result else {
                completion(.failure(CalendarError.invalidResponse))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(CalendarEventsListResponse.self, from: data)
                let items = decoded.items ?? []

                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                let dateOnly = DateFormatter()
                dateOnly.calendar = calendar
                dateOnly.locale = Locale(identifier: "en_US_POSIX")
                dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
                dateOnly.dateFormat = "yyyy-MM-dd"

                func parseEventTime(_ obj: CalendarEventsListResponse.Event.EventDateTime) -> (date: Date, isAllDay: Bool)? {
                    if let dt = obj.dateTime, let d = iso.date(from: dt) {
                        return (d, false)
                    }
                    if let d = obj.date, let dateVal = dateOnly.date(from: d) {
                        return (dateVal, true)
                    }
                    return nil
                }

                var events: [DayEvent] = []
                events.reserveCapacity(items.count)

                for event in items {
                    guard let startObj = event.start, let endObj = event.end else { continue }
                    guard let parsedStart = parseEventTime(startObj), let parsedEnd = parseEventTime(endObj) else { continue }

                    let id = event.id ?? UUID().uuidString
                    let title = (event.summary?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Busy"

                    let isAllDay = parsedStart.isAllDay || parsedEnd.isAllDay
                    let start: Date
                    let end: Date
                    if isAllDay {
                        start = startOfDay
                        end = endOfDay
                    } else {
                        start = parsedStart.date
                        end = parsedEnd.date
                    }

                    if end > start {
                        events.append(DayEvent(id: id, title: title, start: start, end: end, isAllDay: isAllDay))
                    }
                }

                completion(.success(events.sorted { $0.start < $1.start }))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
