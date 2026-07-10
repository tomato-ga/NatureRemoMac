import SwiftUI

struct NoticeView: View {
    @EnvironmentObject private var store: RemoStore

    var body: some View {
        if let notice = store.notice {
            HStack(spacing: 8) {
                Image(systemName: notice.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(notice.kind == .success ? .green : .orange)
                Text(notice.message)
                    .lineLimit(2)
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        store.dismissNotice(id: notice.id)
                    }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(NaturePalette.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(NaturePalette.divider, lineWidth: 0.5)
            }
            .shadow(color: NaturePalette.ink.opacity(0.045), radius: 5, y: 2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: notice.id) {
                do {
                    try await Task.sleep(nanoseconds: dismissDelay(for: notice))
                } catch {
                    return
                }

                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.18)) {
                        store.dismissNotice(id: notice.id)
                    }
                }
            }
        }
    }

    private func dismissDelay(for notice: RemoStore.Notice) -> UInt64 {
        switch notice.kind {
        case .success:
            return 3_500_000_000
        case .failure:
            return 6_000_000_000
        }
    }
}
