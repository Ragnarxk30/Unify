import SwiftUI

struct LoginView: View {
    // Callback, der bei erfolgreichem Login aufgerufen wird (kommt aus SharedCalendarApp)
    let onSuccess: () -> Void

    // Eingaben
    @State private var username: String = ""
    @State private var password: String = ""

    // UI-Status
    @State private var isSecure: Bool = true
    @State private var errorMessage: String?

    // Navigation (Push zur Registrierung)
    @State private var showRegister: Bool = false

    // Demo-Credentials
    private let demoUsername = "demo"
    private let demoPassword = "1234"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // App/Brand
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.blue)
                    Text("Unify")
                        .font(.largeTitle.weight(.bold))
                }

                // Eingabefelder
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Benutzername").font(.subheadline).foregroundStyle(.secondary)
                        TextField("z. B. demo", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Passwort").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 0) {
                            if isSecure {
                                SecureField("z. B. 1234", text: $password)
                                    .textContentType(.password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            } else {
                                TextField("z. B. 1234", text: $password)
                                    .textContentType(.password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }

                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isSecure.toggle()
                                }
                            } label: {
                                Image(systemName: isSecure ? "eye" : "eye.slash")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Fehlerhinweis
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Aktionen
                VStack(spacing: 12) {
                    Button {
                        login()
                    } label: {
                        Text("Anmelden")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    // Push zur Demo-Registrierungsansicht
                    Button {
                        showRegister = true
                    } label: {
                        Text("Noch keinen Account? Registrieren")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.vertical, 24)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationDestination(isPresented: $showRegister) {
                DemoRegisterView()
                    .navigationTitle("Registrierung")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - Login-Logik (Demo)
    private func login() {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !u.isEmpty, !p.isEmpty else {
            errorMessage = "Bitte Benutzername und Passwort eingeben."
            return
        }

        // Reine Demo: akzeptiere nur die festen Demo-Zugangsdaten
        if u == demoUsername && p == demoPassword {
            errorMessage = nil
            onSuccess()
        } else {
            errorMessage = "Ungültige Zugangsdaten."
        }
    }
}

// Schlanke, interne Demo-Registrierungsansicht (keine Persistenz, nur UI)
private struct DemoRegisterView: View {
    @State private var email = ""
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    // Einfache Demo-Validierung
    private var canSubmit: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let u = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailLooksValid = e.contains("@") && e.contains(".")
        return !e.isEmpty && emailLooksValid &&
               !u.isEmpty &&
               !p.isEmpty &&
               !c.isEmpty &&
               p == c
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Konto erstellen")
                    .font(.title2.weight(.bold))
            }

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("E-Mail").font(.subheadline).foregroundStyle(.secondary)
                    TextField("Bitte E-Mail eingeben", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Benutzername").font(.subheadline).foregroundStyle(.secondary)
                    TextField("Bitte Benutzername eingeben", text: $newUsername)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Passwort").font(.subheadline).foregroundStyle(.secondary)
                    SecureField("Mind. 4 Zeichen", text: $newPassword)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Passwort bestätigen").font(.subheadline).foregroundStyle(.secondary)
                    SecureField("Passwort bestätigen", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                Button {
                    // reine Demo – keine Persistenz
                    print("Account erstellt (Demo).")
                } label: {
                    Text("Account erstellen")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent) // gleicher Stil wie „Anmelden“
                .disabled(!canSubmit)            // nur aktiv, wenn alle 4 Felder korrekt sind
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.vertical, 24)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    LoginView {
        // Preview: no-op
    }
}
