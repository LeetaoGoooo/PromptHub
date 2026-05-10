import AppKit
import GenKit
import SwiftUI

// MARK: - ServiceModel

struct ServiceModel: Hashable, Identifiable {
    let service: Service
    let model: Model

    var id: String { "\(service.id)-\(model.id)" }
    var displayName: String { "\(service.name) - \(model.id)" }

    func hash(into hasher: inout Hasher) { hasher.combine(service.id); hasher.combine(model.id) }
    static func == (lhs: ServiceModel, rhs: ServiceModel) -> Bool { lhs.service.id == rhs.service.id && lhs.model.id == rhs.model.id }
}

// MARK: - TestResult

@Observable
class TestResult {
    var content: String = ""
    var isLoading: Bool = false
    var error: String? = nil
    var hasError: Bool { error != nil }

    init(content: String = "", isLoading: Bool = false, error: String? = nil) {
        self.content = content; self.isLoading = isLoading; self.error = error
    }
}

// MARK: - TestResultCard

struct TestResultCard: View {
    let serviceModel: ServiceModel
    let result: TestResult

    @State private var isExpanded = true
    @State private var showingFullScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TestResultHeader(serviceModel: serviceModel, result: result, isExpanded: $isExpanded, onFullScreen: { showingFullScreen = true })
            if isExpanded { TestResultContent(result: result).transition(.slide.combined(with: .opacity)) }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .sheet(isPresented: $showingFullScreen) { TestResultFullScreenView(serviceModel: serviceModel, result: result) }
    }
}

// MARK: - TestResultHeader

struct TestResultHeader: View {
    let serviceModel: ServiceModel
    let result: TestResult
    @Binding var isExpanded: Bool
    let onFullScreen: () -> Void

    var body: some View {
        HStack {
            Button { isExpanded.toggle() } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.caption).foregroundColor(.secondary)
            }.buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(serviceModel.service.name).font(.headline).foregroundColor(.primary)
                Text(serviceModel.model.id).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                if !result.content.isEmpty && result.error == nil {
                    Button { onFullScreen() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption) }
                        .buttonStyle(PlainButtonStyle()).help("View in full screen")
                }
                Group {
                    if result.isLoading { ProgressView().scaleEffect(0.7) }
                    else if result.error != nil { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange) }
                    else if !result.content.isEmpty { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                }
            }
        }
        .padding(16).contentShape(Rectangle()).onTapGesture { isExpanded.toggle() }
    }
}

// MARK: - TestResultContent

struct TestResultContent: View {
    let result: TestResult
    @Environment(\.colorScheme) private var colorScheme

    private var contentBackgroundColor: Color { colorScheme == .dark ? Color(NSColor.textBackgroundColor) : Color.white }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            if let error = result.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text("Error: \(error)").foregroundColor(.red).font(.caption)
                }.padding(16).background(Color.red.opacity(0.05))
            } else {
                ScrollView {
                    Text(result.content.isEmpty ? "No result yet..." : result.content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(result.content.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(16)
                }
                .background(contentBackgroundColor)
                .overlay(Rectangle().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
                .frame(maxHeight: 200)
            }
        }
    }
}

// MARK: - TestResultFullScreenView

struct TestResultFullScreenView: View {
    let serviceModel: ServiceModel
    let result: TestResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var fullScreenBackgroundColor: Color { colorScheme == .dark ? Color(NSColor.textBackgroundColor) : Color.white }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(serviceModel.service.name).font(.title2).fontWeight(.semibold)
                    Text(serviceModel.model.id).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }.padding()
            Divider()
            if let error = result.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange)
                    Text("Error occurred").font(.headline)
                    Text(error).font(.body).foregroundColor(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(result.content.isEmpty ? "No result yet..." : result.content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(result.content.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding()
                }.background(fullScreenBackgroundColor)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
