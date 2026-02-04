import Foundation

struct ScheduleConfig: Codable, Identifiable {
    var id: String
    var name: String
    var enabled: Bool
    var promptFile: String
    var schedule: ScheduleTiming
    var options: ScheduleOptions

    /// Computes the next fire date from now, based on the schedule timing.
    func nextFireDate(after date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let components = schedule.timeComponents
        guard let hour = components.hour, let minute = components.minute else { return nil }

        let allowedWeekdays = schedule.weekdayNumbers
        // Try today and the next 7 days to find the next valid fire time.
        for dayOffset in 0..<8 {
            guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            var fireComponents = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            fireComponents.hour = hour
            fireComponents.minute = minute
            fireComponents.second = 0

            guard let fireDate = calendar.date(from: fireComponents) else { continue }
            // Must be in the future.
            guard fireDate > date else { continue }
            // Must be on an allowed weekday (if specified).
            let weekday = calendar.component(.weekday, from: fireDate)
            if !allowedWeekdays.isEmpty && !allowedWeekdays.contains(weekday) { continue }

            return fireDate
        }
        return nil
    }
}

struct ScheduleTiming: Codable {
    var type: String  // "daily"
    var time: String  // "HH:mm"
    var daysOfWeek: [String]?  // ["mon", "tue", ...]

    /// Parses the "HH:mm" time string into date components.
    var timeComponents: DateComponents {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        var components = DateComponents()
        if parts.count >= 2 {
            components.hour = parts[0]
            components.minute = parts[1]
        }
        return components
    }

    /// Converts day-of-week abbreviations to Calendar weekday numbers (1=Sun, 2=Mon, ...).
    var weekdayNumbers: [Int] {
        let map: [String: Int] = [
            "sun": 1, "mon": 2, "tue": 3, "wed": 4,
            "thu": 5, "fri": 6, "sat": 7
        ]
        return (daysOfWeek ?? []).compactMap { map[$0.lowercased()] }
    }
}

struct ScheduleOptions: Codable {
    var activateClaude: Bool?
    var newConversation: Bool?
    var waitForResponse: Bool?

    init(activateClaude: Bool? = true, newConversation: Bool? = true, waitForResponse: Bool? = false) {
        self.activateClaude = activateClaude
        self.newConversation = newConversation
        self.waitForResponse = waitForResponse
    }
}
