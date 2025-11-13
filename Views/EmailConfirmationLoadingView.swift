import SwiftUI

struct EmailConfirmationLoadingView: View {
    @EnvironmentObject private var session: SessionStore
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Bestätige deine Email")
                .font(.title2)
                .bold()
            
            Text("Wir haben dir eine Bestätigungs-Email gesendet. Bitte klicke auf den Link in der Email um fortzufahren.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Abbrechen") {
                session.setWaitingForEmailConfirmation(false)
            }
            .foregroundColor(.red)
        }
        .padding()
    }
}
