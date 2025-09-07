import SwiftUI

/// Quick add bar for creating tasks and events with natural language parsing
struct QuickAddBar: View {
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    @FocusState private var isTextFieldFocused: Bool
    
    @State private var quickAddParser: QuickAddParser?
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var onItemCreated: ((ParsedItem) -> Void)?
    
    init(onItemCreated: ((ParsedItem) -> Void)? = nil) {
        self.onItemCreated = onItemCreated
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: UITheme.Spacing.sm) {
                // Input field
                TextField("Add task or event...", text: $inputText)
                    .textFieldStyle(QuickAddTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        processInput()
                    }
                    .disabled(isProcessing)
                
                // Add button
                Button(action: processInput) {
                    Group {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
                .foregroundColor(inputText.isEmpty ? UITheme.Colors.tertiary : UITheme.Colors.primary)
                .disabled(inputText.isEmpty || isProcessing)
                .animation(UITheme.Animation.quick, value: inputText.isEmpty)
            }
            .padding(UITheme.Spacing.md)
            .background(UITheme.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: UITheme.CornerRadius.large)
                    .stroke(isTextFieldFocused ? UITheme.Colors.primary : UITheme.Colors.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: UITheme.CornerRadius.large))
            
            // Suggestion hints
            if !inputText.isEmpty && !isTextFieldFocused {
                suggestionHints
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Error message
            if let errorMessage = errorMessage {
                errorView(errorMessage)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(UITheme.Animation.standard, value: isTextFieldFocused)
        .animation(UITheme.Animation.standard, value: errorMessage)
        .onAppear {
            if quickAddParser == nil {
                quickAddParser = QuickAddParser()
            }
        }
    }
    
    private var suggestionHints: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UITheme.Spacing.sm) {
                suggestionChip("@label", description: "Add labels")
                suggestionChip("#project", description: "Set project")
                suggestionChip("p1-p4", description: "Set priority")
                suggestionChip("tomorrow 3pm", description: "Set time")
                suggestionChip("every week", description: "Repeat")
                suggestionChip("remind 30m", description: "Reminder")
            }
            .padding(.horizontal, UITheme.Spacing.md)
        }
        .padding(.top, UITheme.Spacing.xs)
    }
    
    private func suggestionChip(_ text: String, description: String) -> some View {
        HStack(spacing: UITheme.Spacing.xs) {
            Text(text)
                .font(UITheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(UITheme.Colors.primary)
            
            Text(description)
                .font(UITheme.Typography.caption2)
                .foregroundColor(UITheme.Colors.secondaryText)
        }
        .padding(.horizontal, UITheme.Spacing.sm)
        .padding(.vertical, UITheme.Spacing.xs)
        .background(UITheme.Colors.primary.opacity(0.1))
        .clipShape(Capsule())
        .onTapGesture {
            appendToInput(text + " ")
        }
    }
    
    private func errorView(_ message: String) -> some View {
        HStack(spacing: UITheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(UITheme.Colors.error)
                .font(.caption)
            
            Text(message)
                .font(UITheme.Typography.caption)
                .foregroundColor(UITheme.Colors.error)
            
            Spacer()
            
            Button("Dismiss") {
                withAnimation(UITheme.Animation.quick) {
                    errorMessage = nil
                }
            }
            .font(UITheme.Typography.caption)
            .foregroundColor(UITheme.Colors.primary)
        }
        .padding(UITheme.Spacing.sm)
        .background(UITheme.Colors.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: UITheme.CornerRadius.small))
        .padding(.top, UITheme.Spacing.xs)
    }
    
    private func processInput() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let parser = quickAddParser else { return }
        
        isProcessing = true
        hapticFeedback.impactOccurred()
        
        // Clear previous error
        errorMessage = nil
        
                    _Concurrency.Task {
            do {
                // Parse the input
                guard let parsed = parser.parse(inputText) else {
                    throw QuickAddError.parsingFailed
                }
                
                // Create the item
                if parsed.type == .task {
                    _ = try parser.createTask(from: parsed)
                } else {
                    _ = try parser.createEvent(from: parsed, useEventKit: false) // Use Core Data for now
                }
                
                await MainActor.run {
                    // Success feedback
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    
                    // Clear input
                    inputText = ""
                    isProcessing = false
                    isTextFieldFocused = false
                    
                    // Notify parent
                    onItemCreated?(parsed)
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func appendToInput(_ text: String) {
        inputText += text
        isTextFieldFocused = true
    }
}

// MARK: - Custom Text Field Style

struct QuickAddTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(UITheme.Typography.body)
            .padding(.vertical, UITheme.Spacing.sm)
            .background(Color.clear)
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct QuickAddBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: UITheme.Spacing.lg) {
            QuickAddBar { item in
                print("Created item: \(item.title)")
            }
            
            Spacer()
        }
        .padding()
        .background(UITheme.Colors.groupedBackground)
        .previewDisplayName("Light Mode")
        
        VStack(spacing: UITheme.Spacing.lg) {
            QuickAddBar { item in
                print("Created item: \(item.title)")
            }
            
            Spacer()
        }
        .padding()
        .background(UITheme.Colors.groupedBackground)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}

// Preview with sample suggestions
struct QuickAddBarWithSamples: View {
    @State private var showingSamples = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: UITheme.Spacing.md) {
            QuickAddBar { item in
                print("Created: \(item.title)")
            }
            
            if showingSamples {
                VStack(alignment: .leading, spacing: UITheme.Spacing.sm) {
                    Text("Try these examples:")
                        .font(UITheme.Typography.caption)
                        .foregroundColor(UITheme.Colors.secondaryText)
                    
                    VStack(alignment: .leading, spacing: UITheme.Spacing.xs) {
                        sampleText("Math homework #school @urgent p1 due tomorrow")
                        sampleText("Team meeting 3-4pm tomorrow #work")
                        sampleText("Review paper @research remind 1h")
                        sampleText("Gym workout every monday @health")
                    }
                }
                .themeCard()
            }
        }
    }
    
    private func sampleText(_ text: String) -> some View {
        Text(text)
            .font(UITheme.Typography.caption)
            .foregroundColor(UITheme.Colors.secondaryText)
            .padding(.horizontal, UITheme.Spacing.sm)
            .padding(.vertical, UITheme.Spacing.xs)
            .background(UITheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: UITheme.CornerRadius.small))
    }
}

struct QuickAddBarSamples_Previews: PreviewProvider {
    static var previews: some View {
        QuickAddBarWithSamples()
            .padding()
            .background(UITheme.Colors.groupedBackground)
    }
}
#endif
