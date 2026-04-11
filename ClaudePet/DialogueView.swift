import SwiftUI

// MARK: - DialogueView
// 한 줄 또는 여러 줄 대사를 반투명 검은 박스 위에 흰 텍스트로 표시합니다.
// .allowsHitTesting(false) 가 적용되어 있어 클릭 이벤트가 완전히 통과됩니다.

struct DialogueView: View {
    let text:  String
    let scale: CGFloat   // uiScale (0.5 / 1.0 / 2.0)

    var body: some View {
        Text(text)
            .font(.system(size: 11 * scale, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10 * scale)
            .padding(.vertical,    6  * scale)
            .background(
                RoundedRectangle(cornerRadius: 7 * scale)
                    .fill(Color.black.opacity(0.50))
            )
            .allowsHitTesting(false)
    }
}

// MARK: - DialogueWindowContent
// 대사 전용 NSPanel 의 루트 뷰입니다.
// DialogueManager.shared 를 직접 구독하므로 별도 파라미터 전달이 필요 없습니다.
// 패널 자체가 ignoresMouseEvents = true 이므로 클릭 차단은 창 레벨에서 처리됩니다.

struct DialogueWindowContent: View {
    @ObservedObject private var manager = DialogueManager.shared

    // 배율 변경 시 DialogueView 를 새 scale 로 다시 그립니다.
    @State private var uiScale: CGFloat = SettingsManager.shared.uiScale

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear  // 패널 전체를 투명하게 유지

            if let text = manager.currentText {
                DialogueView(text: text, scale: uiScale)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)),
                            removal:   .opacity
                        )
                    )
            }
        }
        .animation(.easeInOut(duration: 0.18), value: manager.currentText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: SettingsManager.didChange)) { _ in
            uiScale = SettingsManager.shared.uiScale
        }
    }
}
