import AppKit

/// 앱 전역 설정 (독 아이콘 숨김 / 앱 크기 배율)을 관리하는 싱글톤.
/// 변경 즉시 UserDefaults 에 저장하고 NotificationCenter 로 변경을 알립니다.
final class SettingsManager {
    static let shared = SettingsManager()

    // MARK: - Notification

    /// 설정이 바뀔 때 NotificationCenter 로 브로드캐스트됩니다.
    static let didChange = Notification.Name("SettingsManagerDidChange")

    // MARK: - UserDefaults Keys

    private enum Key {
        static let hideDockIcon = "settings_hideDockIcon"
        static let scaleIndex   = "settings_scaleIndex"
    }

    // MARK: - 독 아이콘 숨김

    /// true 면 Dock 에서 앱 아이콘을 제거합니다 (.accessory 정책).
    var hideDockIcon: Bool {
        didSet {
            guard hideDockIcon != oldValue else { return }
            UserDefaults.standard.set(hideDockIcon, forKey: Key.hideDockIcon)
            applyDockPolicy()
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    // MARK: - 앱 크기 배율

    /// 0 = 0.5배 / 1 = 1배(기본) / 2 = 2배
    var scaleIndex: Int {
        didSet {
            guard scaleIndex != oldValue else { return }
            UserDefaults.standard.set(scaleIndex, forKey: Key.scaleIndex)
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    /// 선택된 배율에 해당하는 스프라이트 스케일 (baseSpriteSize 에 곱할 값).
    var spriteScale: CGFloat {
        switch scaleIndex {
        case 0:  return 1.5   // 0.5배 → 32 × 1.5 = 48 px
        case 2:  return 6.0   // 2배   → 32 × 6.0 = 192 px
        default: return 3.0   // 1배   → 32 × 3.0 = 96 px (기본)
        }
    }

    /// 1배(기본) 대비 UI 배율. 0.5배=0.5, 1배=1.0, 2배=2.0
    var uiScale: CGFloat { spriteScale / 3.0 }

    /// 사람이 읽기 좋은 배율 레이블.
    var scaleLabel: String {
        switch scaleIndex {
        case 0:  return "0.5배"
        case 2:  return "2배"
        default: return "1배"
        }
    }

    // MARK: - Init

    private init() {
        let savedHide  = UserDefaults.standard.bool(forKey: Key.hideDockIcon)
        let savedScale = UserDefaults.standard.object(forKey: Key.scaleIndex) as? Int ?? 1

        self.hideDockIcon = savedHide
        self.scaleIndex   = max(0, min(2, savedScale))

        // 저장된 설정을 시작 즉시 적용
        applyDockPolicy()
    }

    // MARK: - Private Helpers

    private func applyDockPolicy() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(self.hideDockIcon ? .accessory : .regular)
        }
    }
}
