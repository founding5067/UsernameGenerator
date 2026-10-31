//
//  KeyboardView.swift
//  UsernameKeyboard
//

import SwiftUI
import UIKit

struct KeyboardView: View {
    let host: KeyboardHost
    let controller: UIInputViewController
    let insert: (String) -> Void
    let deleteBackward: () -> Void

    // Only these choices are remembered, in the keyboard's own storage. Usernames are never stored.
    @AppStorage("keyboard.wordCount") private var wordCount = 2
    @AppStorage("keyboard.includeNumber") private var includeNumber = true
    @AppStorage("keyboard.maxLength") private var maxLength = 0

    @State private var usernames: [String] = []

    private static let batchSize = 4
    private static let wordCounts = [1, 2, 3]
    private static let maxLengths = [0, 12, 15, 20]

    private var options: UsernameOptions {
        UsernameOptions(
            wordCount: wordCount,
            includeNumber: includeNumber,
            limitLength: maxLength > 0,
            maxLength: maxLength > 0 ? maxLength : UsernameOptions().maxLength
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            optionsRow
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(usernames, id: \.self) { name in
                    Button {
                        insert(name)
                        generate()
                    } label: {
                        Text(name)
                            .font(.system(.body, design: .monospaced, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(keyBackground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Types this username")
                }
            }
            bottomRow
        }
        .padding(8)
        .onAppear(perform: generate)
        .onChange(of: options) { generate() }
    }

    private var optionsRow: some View {
        HStack(spacing: 10) {
            Picker("Words", selection: $wordCount) {
                ForEach(Self.wordCounts, id: \.self) { Text($0 == 1 ? "1 word" : "\($0) words").tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Digits", isOn: $includeNumber)
                .toggleStyle(.button)
                .tint(.accentColor)
            Picker("Length", selection: $maxLength) {
                ForEach(Self.maxLengths, id: \.self) { Text($0 == 0 ? "No limit" : "Max \($0)").tag($0) }
            }
            .pickerStyle(.menu)
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 8) {
            if host.showsGlobe {
                GlobeButton(controller: controller)
                    .frame(width: 52, height: 44)
                    .background(keyBackground)
            }
            Button(action: generate) {
                Label("New usernames", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(keyBackground)
            }
            .buttonStyle(.plain)
            DeleteKey(delete: deleteBackward)
                .background(keyBackground)
        }
    }

    private var keyBackground: some View {
        RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemFill))
    }

    private func generate() {
        usernames = UsernameGenerator().generateBatch(options: options, count: Self.batchSize)
    }
}

/// Deletes once when touched, then keeps deleting while held, like the system keyboard's delete key.
private struct DeleteKey: View {
    let delete: () -> Void

    /// Resets by itself when the touch ends or is cancelled, so the repeating can never get stuck on.
    @GestureState private var isPressed = false
    @State private var repeating: Task<Void, Never>?

    var body: some View {
        Image(systemName: "delete.left")
            .frame(width: 52, height: 44)
            .opacity(isPressed ? 0.5 : 1)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).updating($isPressed) { _, pressed, _ in pressed = true })
            .onChange(of: isPressed) {
                if isPressed {
                    delete()
                    repeating = Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        while !Task.isCancelled {
                            delete()
                            try? await Task.sleep(for: .milliseconds(70))
                        }
                    }
                } else {
                    repeating?.cancel()
                    repeating = nil
                }
            }
            .onDisappear {
                repeating?.cancel()
                repeating = nil
            }
            .accessibilityLabel("Delete")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, delete)
    }
}

/// UIKit owns the next-keyboard behavior, so the globe key is a real `UIButton` wired to the controller.
private struct GlobeButton: UIViewRepresentable {
    let controller: UIInputViewController

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.tintColor = .label
        button.accessibilityLabel = "Next keyboard"
        button.addTarget(controller, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
