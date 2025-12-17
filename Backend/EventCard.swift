//
//  EventCard.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 23.11.25.
//


import SwiftUI

struct EventCard: View {
    let event: Event
    var onTap: ((Event) -> Void)? = nil
    var onLongPress: ((Event) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(.title3).bold()
                .foregroundStyle(.primary)

            Text(Self.format(event.starts_at, event.ends_at))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let details = event.details,
               !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
        }
        .cardStyle()
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?(event)
        }
        .onLongPressGesture {
            onLongPress?(event)
        }
    }

    static func format(_ start: Date, _ end: Date) -> String {
        let cal = Calendar.current
        let sameDay = cal.isDate(start, inSameDayAs: end)

        let dfDateTime = DateFormatter()
        dfDateTime.locale = .current
        dfDateTime.dateFormat = "dd.MM.yy, HH:mm"

        if sameDay {
            let dfDate = DateFormatter()
            dfDate.locale = .current
            dfDate.dateFormat = "dd.MM.yy, HH:mm"

            let dfTime = DateFormatter()
            dfTime.locale = .current
            dfTime.dateFormat = "HH:mm"

            return "\(dfDate.string(from: start)) – \(dfTime.string(from: end))"
        } else {
            return "\(dfDateTime.string(from: start)) – \(dfDateTime.string(from: end))"
        }
    }
}