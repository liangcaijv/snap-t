import SwiftUI

enum TranslationOverlayState: Equatable {
    case loading
    case translated(String)
    case failure(String)
    case noText
}

struct TranslationOverlayView: View {
    let state: TranslationOverlayState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: true) {
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        )
    }

    private var title: String {
        switch state {
        case .loading:
            return "Translating"
        case .translated:
            return "Translation"
        case .failure:
            return "Translation Failed"
        case .noText:
            return "No Text"
        }
    }

    private var message: String {
        switch state {
        case .loading:
            return "Translating..."
        case let .translated(text):
            return text
        case let .failure(message):
            return message
        case .noText:
            return "No text recognized."
        }
    }
}
