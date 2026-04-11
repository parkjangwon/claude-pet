import Foundation

// MARK: - 특수 애니메이션 엔트리
// 호감도 마일스톤 레벨에서 해금되는 특수 애니메이션을 정의합니다.
//
// [새 특수 애니메이션 추가 방법]
// 1. PetAnimation.swift 에 새 PetAnimationState 케이스를 추가합니다.
// 2. 아래 AffinitySpecialAnimationRegistry.entries 배열에 항목을 추가합니다.
// 3. AnimationController 에서 didUnlockSpecialAnimation 알림을 받아 처리합니다.
//
// [해금 주기 설정]
// PetConfiguration.swift 의 affinityAnimationUnlockStep 값을 변경하면
// 몇 레벨마다 특수 애니메이션이 해금될지 조정됩니다. (기본: 10레벨)
struct AffinitySpecialAnimationEntry {
    /// 해금에 필요한 호감도 레벨 (PetConfig.affinityAnimationUnlockStep 의 배수여야 합니다)
    let unlockLevel: Int

    /// 해금되는 애니메이션의 식별자 (PetAnimationState 의 rawValue 또는 커스텀 ID)
    /// 추후 PetAnimationState 에 케이스를 추가한 뒤 연결하세요.
    let animationID: String

    /// 해금 시 표시할 대사 (nil 이면 기본 레벨업 메시지 사용)
    let unlockDialogue: String?

    /// 사람이 읽을 수 있는 애니메이션 이름 (로그/디버그용)
    let displayName: String
}

// MARK: - 특수 애니메이션 레지스트리
// 모든 특수 애니메이션 해금 조건을 여기서 한 곳에 관리합니다.
enum AffinitySpecialAnimationRegistry {

    /// 등록된 특수 애니메이션 전체 목록.
    /// unlockLevel 은 반드시 PetConfig.affinityAnimationUnlockStep 의 배수로 설정하세요.
    static let entries: [AffinitySpecialAnimationEntry] = [

        // ── Lv 10 해금 ──────────────────────────────────────────────────────
        // TODO: Lv10 전용 애니메이션 에셋 추가 후 animationID 를 실제 케이스명으로 교체하세요.
        AffinitySpecialAnimationEntry(
            unlockLevel:    10,
            animationID:    "specialLevel10",   // 추후 PetAnimationState 케이스명으로 교체
            unlockDialogue: "레벨 10 달성!! 특별한 모습 보여줄게요~!",
            displayName:    "Lv10 특별 반응"
        ),

        // ── Lv 20 해금 ──────────────────────────────────────────────────────
        AffinitySpecialAnimationEntry(
            unlockLevel:    20,
            animationID:    "specialLevel20",
            unlockDialogue: "레벨 20!! 우리 사이가 더 특별해졌어요~!",
            displayName:    "Lv20 특별 반응"
        ),

        // ── Lv 30 해금 ──────────────────────────────────────────────────────
        AffinitySpecialAnimationEntry(
            unlockLevel:    30,
            animationID:    "specialLevel30",
            unlockDialogue: "레벨 30!! 정말 오래 함께했네요~!",
            displayName:    "Lv30 특별 반응"
        ),

        // ── 이하 동일한 패턴으로 계속 추가 ─────────────────────────────────
        // AffinitySpecialAnimationEntry(
        //     unlockLevel:    40,
        //     animationID:    "specialLevel40",
        //     unlockDialogue: "레벨 40!! ...",
        //     displayName:    "Lv40 특별 반응"
        // ),
    ]

    // MARK: - 조회 API

    /// 특정 해금 레벨에 해당하는 엔트리를 반환합니다.
    static func entry(forUnlockLevel level: Int) -> AffinitySpecialAnimationEntry? {
        entries.first { $0.unlockLevel == level }
    }

    /// 현재 호감도 레벨까지 해금된 모든 엔트리를 반환합니다.
    static func unlockedEntries(forLevel level: Int) -> [AffinitySpecialAnimationEntry] {
        entries.filter { $0.unlockLevel <= level }
    }

    /// 특정 animationID 가 현재 레벨에서 해금됐는지 확인합니다.
    static func isUnlocked(animationID: String, atLevel level: Int) -> Bool {
        guard let entry = entries.first(where: { $0.animationID == animationID }) else {
            return false
        }
        return level >= entry.unlockLevel
    }
}
