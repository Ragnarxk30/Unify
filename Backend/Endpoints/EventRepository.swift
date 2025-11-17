//
//  EventRepository.swift 
//  Unify
//
//  Created by Jonas Dunkenberger on 16.11.25.
//


//
//  EventRepository.swift
//  Unify
//
//  Created by Jonas Dunkenberger on 16.11.25.
//


//  EventRepository.swift
//  Unify

import Foundation

protocol EventRepository {
    /// Erstellt ein Event in einer Gruppe.
    /// - Parameters:
    ///   - groupId: Zielgruppe
    ///   - title: Titel des Events
    ///   - details: optionale Beschreibung
    ///   - startsAt: Startzeit
    ///   - endsAt: optionale Endzeit
    func create(
        groupId: UUID,
        title: String,
        details: String?,
        startsAt: Date,
        endsAt: Date?
    ) async throws
    
    /// Event vollständig bearbeiten
    func update(
        eventId: UUID,
        title: String,
        details: String?,
        startsAt: Date,
        endsAt: Date?
    ) async throws
    
    /// Event löschen
    func delete(eventId: UUID) async throws
    
    /// Alle Events einer Gruppe laden (RLS regelt Sichtbarkeit)
    func listForGroup(_ groupId: UUID) async throws -> [Event]
    
    //Listet alle Events die ein User sehen darf
    func listUserEvents() async throws -> [Event]
}
