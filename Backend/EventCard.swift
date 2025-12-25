//
//  EventCard.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 23.11.25.
//

import SwiftUI

struct EventCard: View {
    let event: Event
    let group: AppGroup?
    var onTap: ((Event) -> Void)? = nil
    var onLongPress: ((Event) -> Void)? = nil
    
    private var eventColor: Color {
        if let groupId = event.group_id {
            let hash = groupId.uuidString.hashValue
            let idx = abs(hash) % colorPalette.count
            return colorPalette[idx]
        }
        return .blue
    }
    
    private var isPersonalEvent: Bool {
        event.group_id == nil
    }
    
    private let colorPalette: [Color] = [
        .blue, .green, .red, .orange, .pink, .purple, .teal, .indigo
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header mit Titel und Zeit
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    // Farbiger Indikator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(eventColor)
                        .frame(width: 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(Self.format(event.starts_at, event.ends_at))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Details wenn vorhanden
                        if let details = event.details,
                           !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(details)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            // Divider
            Divider()
                .padding(.horizontal, 12)
            
            // Footer mit Gruppe und Ersteller
            HStack(spacing: 16) {
                // Gruppe oder "Persönlich"
                HStack(spacing: 6) {
                    Image(systemName: isPersonalEvent ? "person.fill" : "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(eventColor)
                        .frame(width: 20)
                    
                    Text(isPersonalEvent ? "Persönlich" : (group?.name ?? "Unbekannte Gruppe"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Ersteller
                if let creator = event.user {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(creator.display_name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
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
