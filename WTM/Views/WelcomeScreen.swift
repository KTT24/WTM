//
//  WelcomeScreen.swift
//  WTM
//

import SwiftUI
import Supabase

struct WelcomeScreen: View {
    @Environment(\.colorScheme) private var colorScheme

    private enum InputField {
        case email
        case password
        case username
        case phone
        case otp
    }

    private enum AuthMode {
        case signIn
        case signUp

        var title: String { self == .signIn ? "Sign In" : "Sign Up" }
    }

    private enum AuthMethod {
        case email
        case phone

        var title: String { self == .email ? "Email" : "Phone" }
    }

    private enum Step: Int {
        case chooseMode
        case chooseMethod
        case email
        case password
        case username
        case phone
        case otp

        var title: String {
            switch self {
            case .chooseMode: return "Welcome"
            case .chooseMethod: return "Choose a method"
            case .email: return "What’s your email?"
            case .password: return "Create a password"
            case .username: return "Pick a username"
            case .phone: return "What’s your phone?"
            case .otp: return "Enter verification code"
            }
        }

        var subtitle: String {
            switch self {
            case .chooseMode: return "Let’s get you in"
            case .chooseMethod: return "Use email or phone"
            case .email: return "We’ll use this to sign you in"
            case .password: return "At least 6 characters"
            case .username: return "This will be public"
            case .phone: return "Include country code, e.g. +1"
            case .otp: return "Check your SMS for a 6‑digit code"
            }
        }
    }

    @State private var isAnimating = false
    @State private var spinComplete = false

    @State private var mode: AuthMode? = nil
    @State private var method: AuthMethod? = nil
    @State private var step: Step = .chooseMode

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var phone = ""
    @State private var otp = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var otpSent = false
    @State private var showConfetti = false
    @FocusState private var focusedField: InputField?

    @AppStorage("isLoggedIn") private var isLoggedIn = false

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
            Color.black
                .opacity(AdaptiveTheme.backgroundScrimOpacity(for: colorScheme))
                .ignoresSafeArea()

            VStack(spacing: 22) {
                if step == .chooseMode {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.35))
                            .frame(width: 220, height: 220)
                            .scaleEffect(spinComplete ? (isAnimating ? 1.12 : 0.95) : 0.85)
                            .opacity(spinComplete ? (isAnimating ? 0.7 : 0.3) : 0.0)
                            .blur(radius: spinComplete ? (isAnimating ? 18 : 8) : 0)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)

                        Image(systemName: "wineglass.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                            .scaleEffect(isAnimating ? 1.0 : 0.1)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    }

                    VStack(spacing: 8) {
                        Text("WTM")
                            .font(.system(.largeTitle, design: .default, weight: .black))
                            .foregroundStyle(.white)
                            .scaleEffect(isAnimating ? 1.0 : 0.6)
                            .opacity(isAnimating ? 1 : 0)
                            .offset(y: isAnimating ? 0 : 30)

                        Text("Tonight Starts here!")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.92))
                            .opacity(isAnimating ? 1 : 0)
                            .offset(y: isAnimating ? 0 : 20)
                    }
                    .animation(.spring(response: 0.9, dampingFraction: 0.68).delay(0.4), value: isAnimating)

                    Spacer()
                } else {
                    Spacer(minLength: 24)
                }

                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        Text(step.title)
                            .font(.title3.bold())
                            .foregroundStyle(.white)

                        Text(step.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }.padding(10)

                    contentForStep

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    controls
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 40)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 40)
                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.8), value: isAnimating)
            }
        }
        .onAppear {
            withAnimation {
                isAnimating = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                spinComplete = true
                isAnimating = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAnimating = true
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if step != .chooseMode {
                Button {
                    goBack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                            .font(.headline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.18))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .padding(.leading, 16)
                .padding(.top, 12)
            }
        }
        .overlay {
            if showConfetti {
                ConfettiView()
                    .transition(.opacity)
            }
        }
    }

    private var contentForStep: some View {
        Group {
            switch step {
            case .chooseMode:
                HStack(spacing: 12) {
                    actionPill("Sign In", icon: "person.fill", filled: true) {
                        mode = .signIn
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            step = .chooseMethod
                        }
                    }
                    actionPill("Sign Up", icon: "person.badge.plus", filled: false) {
                        mode = .signUp
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            step = .chooseMethod
                        }
                    }
                }
            case .chooseMethod:
                HStack(spacing: 12) {
                    actionPill("Email", icon: "envelope.fill", filled: true) {
                        method = .email
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            step = .email
                        }
                    }
                    actionPill("Phone", icon: "phone.fill", filled: false) {
                        method = .phone
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            step = .phone
                        }
                    }
                }
            case .email:
                onboardingField(
                    "Email",
                    text: $email,
                    icon: "envelope.fill",
                    field: .email,
                    keyboardType: .emailAddress,
                    textInputAutocapitalization: .never,
                    disableAutocorrection: true
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .password:
                onboardingField(
                    "Password",
                    text: $password,
                    icon: "lock.fill",
                    field: .password,
                    isSecure: true
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .username:
                onboardingField(
                    "Username",
                    text: $username,
                    icon: "at",
                    field: .username,
                    textInputAutocapitalization: .never,
                    disableAutocorrection: true
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .phone:
                onboardingField(
                    "Phone (e.g. +15551234567)",
                    text: $phone,
                    icon: "phone.fill",
                    field: .phone,
                    keyboardType: .phonePad
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .otp:
                onboardingField(
                    "6-digit code",
                    text: $otp,
                    icon: "number",
                    field: .otp,
                    keyboardType: .numberPad
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: step)
        .onChange(of: step) { newStep in
            switch newStep {
            case .email:
                focusedField = .email
            case .password:
                focusedField = .password
            case .username:
                focusedField = .username
            case .phone:
                focusedField = .phone
            case .otp:
                focusedField = .otp
            default:
                focusedField = nil
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            if step != .chooseMode {
                Button {
                    Task { await primaryAction() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                        }
                        Image(systemName: primaryButtonIcon)
                        Text(primaryButtonTitle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white)
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading || !canProceed)
            }
        }
    }

    private func actionPill(_ title: String, icon: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.55), lineWidth: filled ? 1.5 : 1.0)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func onboardingField(
        _ placeholder: String,
        text: Binding<String>,
        icon: String,
        field: InputField,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textInputAutocapitalization: TextInputAutocapitalization? = .sentences,
        disableAutocorrection: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .foregroundStyle(.white)
            .tint(.white)
            .textInputAutocapitalization(textInputAutocapitalization)
            .autocorrectionDisabled(disableAutocorrection)
            .keyboardType(keyboardType)
            .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    focusedField == field ? .white.opacity(0.95) : .white.opacity(0.35),
                    lineWidth: focusedField == field ? 1.6 : 1.0
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    private var canProceed: Bool {
        switch step {
        case .chooseMode, .chooseMethod:
            return true
        case .email:
            return email.contains("@") && email.contains(".")
        case .password:
            return password.count >= 6
        case .username:
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .phone:
            return phone.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+") && phone.count >= 8
        case .otp:
            return otp.count >= 4
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .chooseMode: return "Continue"
        case .chooseMethod: return "Continue"
        case .otp: return "Verify"
        default:
            if step == lastStep {
                return mode == .signUp ? "Create Account" : "Sign In"
            }
            return "Next"
        }
    }

    private var primaryButtonIcon: String {
        switch step {
        case .chooseMode, .chooseMethod:
            return "arrow.right.circle.fill"
        case .otp:
            return "checkmark.seal.fill"
        default:
            if step == lastStep {
                return mode == .signUp ? "person.crop.circle.badge.plus" : "person.crop.circle.fill"
            }
            return "arrow.right"
        }
    }

    private var lastStep: Step {
        if method == .email {
            return mode == .signUp ? .username : .password
        }
        if method == .phone {
            return .otp
        }
        return .chooseMethod
    }

    private func goBack() {
        errorMessage = nil
        switch step {
        case .chooseMode:
            break
        case .chooseMethod:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                step = .chooseMode
            }
        case .email:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                step = .chooseMethod
            }
        case .password:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                step = .email
            }
        case .username:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                if method == .phone { step = .phone } else { step = .password }
            }
        case .phone:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                step = .chooseMethod
            }
        case .otp:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                step = method == .phone && mode == .signUp ? .username : .phone
            }
        }
    }

    private func primaryAction() async {
        errorMessage = nil

        switch step {
        case .chooseMode:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                step = .chooseMethod
            }
        case .chooseMethod:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                if method == .email { step = .email } else { step = .phone }
            }
        case .email:
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                step = .password
            }
        case .password:
            if mode == .signUp {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    step = .username
                }
            } else {
                await signInWithEmail()
            }
        case .username:
            if method == .email { await signUpWithEmail() } else { await sendPhoneOtp(isSignup: true) }
        case .phone:
            await sendPhoneOtp(isSignup: mode == .signUp)
        case .otp:
            await verifyPhoneOtp()
        }
    }

    private func signInWithEmail() async {
        guard let mode, mode == .signIn else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await supabase.auth.signIn(email: email, password: password)
            UserDefaults.standard.set(true, forKey: "hasSeenWelcomeScreen")
            UserDefaults.standard.set(false, forKey: "debugForceWelcomeScreen")
            await MainActor.run { isLoggedIn = true }
        } catch {
            await MainActor.run {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        }
    }

    private func signUpWithEmail() async {
        guard let mode, mode == .signUp else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["username": .string(username)]
            )
            UserDefaults.standard.set(true, forKey: "hasSeenWelcomeScreen")
            UserDefaults.standard.set(false, forKey: "debugForceWelcomeScreen")
            await triggerConfetti()
            await MainActor.run { isLoggedIn = true }
        } catch {
            await MainActor.run {
                errorMessage = "Sign up failed: \(error.localizedDescription)"
            }
        }
    }

    private func sendPhoneOtp(isSignup: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if isSignup {
                _ = try await supabase.auth.signInWithOTP(
                    phone: phone,
                    data: ["username": .string(username)]
                )
            } else {
                _ = try await supabase.auth.signInWithOTP(phone: phone)
            }
            otpSent = true
            await MainActor.run { step = .otp }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to send code: \(error.localizedDescription)"
            }
        }
    }

    private func verifyPhoneOtp() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await supabase.auth.verifyOTP(
                phone: phone,
                token: otp,
                type: .sms
            )
            UserDefaults.standard.set(true, forKey: "hasSeenWelcomeScreen")
            UserDefaults.standard.set(false, forKey: "debugForceWelcomeScreen")
            await triggerConfetti()
            await MainActor.run { isLoggedIn = true }
        } catch {
            await MainActor.run {
                errorMessage = "Verification failed: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func triggerConfetti() async {
        withAnimation(.easeInOut(duration: 0.2)) {
            showConfetti = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfetti = false
            }
        }
    }
}

#Preview {
    WelcomeScreen()
}

private struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let size: CGFloat
        let rotation: Double
        let color: Color
        let delay: Double
        let duration: Double
    }

    private let pieces: [Piece] = (0..<36).map { _ in
        let colors: [Color] = [.pink, .yellow, .green, .blue, .orange, .purple]
        return Piece(
            x: CGFloat.random(in: 0.05...0.95),
            size: CGFloat.random(in: 8...16),
            rotation: Double.random(in: 0...360),
            color: colors.randomElement() ?? .white,
            delay: Double.random(in: 0...0.2),
            duration: Double.random(in: 1.0...1.6)
        )
    }

    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.6)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(x: geo.size.width * piece.x, y: animate ? geo.size.height + 40 : -20)
                        .opacity(animate ? 0.1 : 1.0)
                        .animation(
                            .easeIn(duration: piece.duration).delay(piece.delay),
                            value: animate
                        )
                }
            }
            .onAppear { animate = true }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
