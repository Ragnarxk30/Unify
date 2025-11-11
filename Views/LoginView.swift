import SwiftUI

struct LoginView: View {
    let onSuccess: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSecure: Bool = true
    @State private var errorMessage: String?
    @State private var showRegister: Bool = false
    @State private var isLoading: Bool = false

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
                        Text("E-Mail")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("z. B. test@example.com", text: $email)
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
                        Text("Passwort").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 0) {
                            if isSecure {
                                SecureField("Passwort eingeben", text: $password)
                                    .textContentType(.password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            } else {
                                TextField("Passwort eingeben", text: $password)
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
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Anmelden")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                            
                    }
                    .buttonStyle(.bordered)
                
                    .padding(.horizontal, 3)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

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
                RegisterView(onSuccess: onSuccess)
                    .navigationTitle("Registrierung")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - Login-Logik
    private func login() {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !e.isEmpty, !p.isEmpty else {
            errorMessage = "Bitte E-Mail und Passwort eingeben."
            return
        }

        guard e.contains("@") && e.contains(".") else {
            errorMessage = "Bitte eine gültige E-Mail eingeben."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let authService = AuthService()
                let user = try await authService.signIn(email: e, password: p)
                
                await MainActor.run {
                    isLoading = false
                    print("✅ Login erfolgreich: \(user.display_name)")
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Anmeldung fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct RegisterView: View {
    let onSuccess: () -> Void
    
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                    Text("Anzeigename").font(.subheadline).foregroundStyle(.secondary)
                    TextField("Bitte Anzeigename eingeben", text: $name)
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
                    SecureField("Mind. 6 Zeichen", text: $password)
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

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 12) {
                Button {
                    register()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Account erstellen")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit || isLoading)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.vertical, 24)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var canSubmit: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let emailValid = e.contains("@") && e.contains(".")
        return !e.isEmpty && emailValid &&
               !n.isEmpty &&
               !p.isEmpty && p.count >= 6 &&
               !c.isEmpty && p == c
    }

    private func register() {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let authService = AuthService()
                let user = try await authService.signUp(email: e, password: p, name: n)
                
                await MainActor.run {
                    isLoading = false
                    print("✅ Registrierung erfolgreich: \(user.display_name)")
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Registrierung fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    LoginView {
        // Preview: no-op
    }
}
