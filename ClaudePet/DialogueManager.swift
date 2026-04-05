import Combine
import Foundation

/// 대사 상태를 앱 전체에서 공유하는 싱글턴 ObservableObject 입니다.
///
/// ContentView 에서 show() 를 호출하면
/// 별도 NSPanel(DialogueWindowContent) 이 자동으로 반응해 표시됩니다.
///
/// [번역 확장 방법]
/// show() 에 language 파라미터를 추가하거나,
/// DialogueCatalog.randomLine(for:language:) 를 호출하기 전에
/// 현재 언어 설정을 읽도록 ContentView 쪽을 수정하면 됩니다.
final class DialogueManager: ObservableObject {

    // MARK: - 싱글턴
    static let shared = DialogueManager()

    // MARK: - 대사 상태 (읽기 전용 공개)
    @Published private(set) var currentText: String? = nil

    // MARK: - 내부
    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    // MARK: - 공개 API

    /// 대사를 표시합니다.
    /// 이미 대사가 표시 중이면 즉시 교체합니다.
    ///
    /// - Parameters:
    ///   - text: 표시할 문자열
    ///   - duration: 표시 지속 시간(초). 기본값 3.5
    func show(_ text: String, duration: Double = 3.5) {
        hideWorkItem?.cancel()
        currentText = text

        let item = DispatchWorkItem { [weak self] in
            self?.currentText = nil
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }

    /// 표시 중인 대사를 즉시 숨깁니다.
    func hide() {
        hideWorkItem?.cancel()
        currentText = nil
    }
}
