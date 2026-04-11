import Foundation
import Combine

/// 펫 호감도 시스템 싱글턴.
///
/// - 레벨 범위: 1 ~ PetConfig.affinityMaxLevel (100)
/// - 다음 레벨 필요 exp: base * growthRate^(level-1) 의 지수 함수로 증가
/// - 총 누적 호감도(totalAffinity)를 저장하고, 레벨/currentExp/requiredExp 를 파생 계산합니다.
final class AffinityManager: ObservableObject {

    // MARK: - 싱글턴

    static let shared = AffinityManager()

    // MARK: - 알림 이름

    static let didChange              = Notification.Name("AffinityManagerDidChange")
    /// 레벨이 오를 때 발송됩니다. userInfo["newLevel"]: Int
    static let didLevelUp             = Notification.Name("AffinityManagerDidLevelUp")
    /// PetConfig.affinityAnimationUnlockStep 배수 레벨에 도달할 때 발송됩니다.
    /// userInfo["unlockLevel"]: Int
    static let didUnlockSpecialAnimation = Notification.Name("AffinityManagerDidUnlockSpecialAnimation")

    // MARK: - 저장

    private static let storageKey = "petTotalAffinity"

    /// 총 누적 호감도 포인트
    @Published private(set) var totalAffinity: Int

    // MARK: - 파생 값 (computed)

    /// 현재 레벨 (1 ~ affinityMaxLevel)
    var level: Int { info.level }

    /// 현재 레벨 내 누적 exp
    var currentExp: Int { info.currentExp }

    /// 현재 레벨 달성에 필요한 총 exp (maxLevel 에서는 0)
    var requiredExp: Int { info.requiredExp }

    /// 레벨 게이지 진행률 (0.0 ~ 1.0)
    var levelProgress: Double {
        guard requiredExp > 0 else { return 1.0 }
        return Double(currentExp) / Double(requiredExp)
    }

    // MARK: - Private

    private var info: (level: Int, currentExp: Int, requiredExp: Int) {
        Self.computeLevel(from: totalAffinity)
    }

    private init() {
        totalAffinity = UserDefaults.standard.integer(forKey: Self.storageKey)
    }

    // MARK: - 공개 API

    /// 호감도를 amount 만큼 증가시킵니다.
    /// 밥주기 성공 시 HungerManager.feed() 에서 호출합니다.
    func addAffinity(_ amount: Int = PetConfig.affinityPerFeed) {
        let oldLevel = level
        totalAffinity += max(0, amount)
        UserDefaults.standard.set(totalAffinity, forKey: Self.storageKey)
        NotificationCenter.default.post(name: Self.didChange, object: nil)

        let newLevel = level
        if newLevel > oldLevel {
            // 레벨업 알림
            NotificationCenter.default.post(
                name: Self.didLevelUp,
                object: nil,
                userInfo: ["newLevel": newLevel]
            )
            // 특수 애니메이션 해금 체크 (unlock step 의 배수 레벨마다)
            let step = PetConfig.affinityAnimationUnlockStep
            // 구간 내에 해금 포인트가 있는지 확인 (레벨 건너뛰기 대응)
            for lvl in (oldLevel + 1)...newLevel {
                if lvl % step == 0 {
                    NotificationCenter.default.post(
                        name: Self.didUnlockSpecialAnimation,
                        object: nil,
                        userInfo: ["unlockLevel": lvl]
                    )
                }
            }
        }
    }

    /// 현재 레벨까지 해금된 특수 애니메이션 마일스톤 레벨 목록을 반환합니다.
    /// AffinitySpecialAnimation.swift 에서 이 목록을 조회해 실제 애니메이션을 매핑합니다.
    var unlockedAnimationMilestones: [Int] {
        let step = PetConfig.affinityAnimationUnlockStep
        guard level >= step else { return [] }
        return stride(from: step, through: level, by: step).map { $0 }
    }

    /// 특정 레벨의 특수 애니메이션이 해금됐는지 확인합니다.
    func isAnimationUnlocked(atMilestone milestone: Int) -> Bool {
        guard milestone % PetConfig.affinityAnimationUnlockStep == 0 else { return false }
        return level >= milestone
    }

    // MARK: - 레벨 계산 (static — UI 에서도 재사용 가능)

    /// 총 누적 호감도로부터 (레벨, 현재exp, 필요exp) 를 계산합니다.
    static func computeLevel(from total: Int) -> (level: Int, currentExp: Int, requiredExp: Int) {
        let maxLevel = PetConfig.affinityMaxLevel
        var level = 1
        var remaining = total

        while level < maxLevel {
            let req = requiredExpForLevel(level)
            if remaining < req { break }
            remaining -= req
            level += 1
        }

        // maxLevel 달성 시 required = 0
        let req = level < maxLevel ? requiredExpForLevel(level) : 0
        // maxLevel 이면 현재 exp 를 req 로 고정해 게이지가 꽉 차 보이게 표시
        let cur = level < maxLevel ? remaining : 0
        return (level, cur, req)
    }

    /// level 에서 level+1 로 올라가는 데 필요한 exp.
    /// required(level) = ceil(base * growthRate ^ (level - 1))
    static func requiredExpForLevel(_ level: Int) -> Int {
        Int(ceil(Double(PetConfig.affinityBaseExp) *
                 pow(PetConfig.affinityExpGrowthRate, Double(level - 1))))
    }

    // MARK: - [DEBUG] 디버그 전용 — 출시 전 삭제 예정

    /// 호감도를 강제로 amount 만큼 추가합니다.
    func debugAddAffinity(_ amount: Int) {
        addAffinity(amount)
    }

    /// 레벨을 1 올립니다 (현재 레벨 달성에 필요한 나머지 exp 만큼 추가).
    func debugAddOneLevel() {
        guard level < PetConfig.affinityMaxLevel else { return }
        let needed = requiredExp - currentExp
        addAffinity(needed)
    }

    /// 레벨을 1로 초기화합니다 (totalAffinity = 0).
    func debugResetLevel() {
        totalAffinity = 0
        UserDefaults.standard.set(0, forKey: Self.storageKey)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}
