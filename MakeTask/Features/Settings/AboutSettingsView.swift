import SwiftUI

enum MakeTaskInformation {
    static let supportURL = URL(string: "https://github.com/OrhunMahir/MakeTask/issues")!

    static var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "Version \(version) (\(build))"
    }

    static var privacyPolicy: String {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "# MakeTask Privacy Policy\n\nThe privacy policy could not be loaded. Please contact the MakeTask project through Support."
        }
        return text
    }
}

struct AboutSettingsView: View {
    @State private var showsPrivacy = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                        .resizable()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MakeTask").font(.title2.bold())
                        Text(MakeTaskInformation.version).foregroundStyle(.secondary)
                        Text("Your tasks, at home on your desktop.").font(.callout)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Privacy & Support") {
                Text("Your lists stay on this Mac. No account, analytics, or cloud sync.")
                Button("Privacy Policy") { showsPrivacy = true }
                    .accessibilityIdentifier("about.privacy-policy")
                Link("Get Support", destination: MakeTaskInformation.supportURL)
                Text("Support opens GitHub in your browser. Issues are public; leave out private task content.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text(Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? "")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showsPrivacy) { PrivacyPolicyView() }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(MakeTaskInformation.privacyPolicy.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                        if paragraph.hasPrefix("# ") {
                            Text(String(paragraph.dropFirst(2))).font(.title2.bold())
                        } else if paragraph.hasPrefix("## ") {
                            Text(String(paragraph.dropFirst(3))).font(.headline)
                        } else {
                            Text(.init(paragraph)).font(.body)
                        }
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .accessibilityIdentifier("privacy.policy-content")
            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("privacy.done")
            }
            .padding(16)
        }
        .frame(width: 520, height: 500)
    }
}
