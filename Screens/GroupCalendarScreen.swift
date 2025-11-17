import SwiftUI
//
struct GroupCalendarScreen: View {
    let groupID: UUID

    var body: some View {
        GroupMonthlyCalendarView(groupID: groupID) 
            .navigationTitle("Gruppenkalender")
            .navigationBarTitleDisplayMode(.inline)
    }
}
