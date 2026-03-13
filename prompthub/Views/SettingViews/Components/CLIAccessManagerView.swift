import SwiftUI

struct CLIAccessManagerView: View {
    @ObservedObject private var accessManager = CLIDirectoryAccessManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CLI File Access")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("To manage agent skills, PromptHub needs your permission to read and write to specific hidden configuration folders in your Home directory.")
                .font(.body)
                .foregroundColor(.secondary)
            
            List {
                ForEach(CLIDirectory.allCases) { directory in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(directory.displayName)
                                .font(.headline)
                            Text("~/\(directory.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if accessManager.grantedDirectories.contains(directory) {
                            Button("Revoke") {
                                accessManager.revokeAccess(for: directory)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Grant Access") {
                                accessManager.requestAccess(for: directory)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.bordered)
            .frame(minHeight: 300)
            
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 450)
    }
}
