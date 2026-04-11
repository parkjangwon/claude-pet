import Foundation

// MARK: - 지원 언어
// 추후 영어 등 다른 언어를 추가할 때 케이스를 추가하세요.
enum DialogueLanguage: String {
    case korean = "ko"
    // case english = "en"   // 추후 추가 예정
    // case japanese = "ja"  // 추후 추가 예정
}

// MARK: - 대사 트리거 종류
// 각 애니메이션 상태 또는 이벤트에 대응하는 트리거를 정의합니다.
enum DialogueTrigger {
    case idle           // 기본 대기 상태 (랜덤 인터럽트 없이 조용히 있을 때)
    case smile          // 살짝 탭 → Idle_Smile
    case boring         // Idle_Boring 진입
    case jumping        // Idle_Jumping 진입
    case touch          // Force Touch → Idle_Touch
    case workingStart   // 작업 앱 포그라운드 → Idle_Working_Prepare
    case working        // Idle_Working 루프 중 (랜덤 간격으로 출력)
    case workingEnd     // 작업 종료 → Idle_Default 복귀
    case hungry         // 배고픔 수치 20 이하 → Idle_Hungry (힘 없는 느낌)
    case fed            // 밥 받았을 때 반응
}

// MARK: - 대사 카탈로그
// 모든 대사는 이 파일 한 곳에서 관리합니다.
//
// [호감도 대사 티어 시스템]
// - PetConfig.affinityDialogueTierSize (기본 5) 레벨마다 새 대사 세트가 추가됩니다.
// - 기존(Tier 1) 대사는 항상 포함되고, 달성한 티어의 대사가 누적으로 추가됩니다.
//   예) Lv8 → Tier 1 기본 대사 + Tier 2 대사 합산 풀에서 랜덤 선택
//       Lv12 → Tier 1 + Tier 2 + Tier 3 대사 합산
//
// [언어 확장 방법]
// koreanBaseLines / koreanTierLines 과 동일한 구조의 함수를 만들고
// lines(for:level:language:) 의 switch 에 케이스를 추가하면 됩니다.
struct DialogueCatalog {

    // MARK: - 공개 API

    /// 현재 호감도 레벨에 맞는 전체 대사 목록을 반환합니다.
    /// 기본 대사(Tier 1) + 달성한 티어까지의 추가 대사가 누적 합산됩니다.
    static func lines(for trigger: DialogueTrigger,
                      level: Int = 1,
                      language: DialogueLanguage = .korean) -> [String] {
        switch language {
        case .korean:
            return koreanLines(for: trigger, level: level)
        }
    }

    /// 현재 호감도 레벨에 맞는 대사 중 하나를 무작위로 반환합니다.
    /// 대사가 없으면 nil 을 반환합니다.
    static func randomLine(for trigger: DialogueTrigger,
                           level: Int = 1,
                           language: DialogueLanguage = .korean) -> String? {
        return lines(for: trigger, level: level, language: language).randomElement()
    }

    // MARK: - 티어 계산

    /// 호감도 레벨에서 대사 티어를 계산합니다.
    /// 예) level=1 → tier=1, level=6 → tier=2, level=11 → tier=3
    static func affinityDialogueTier(for level: Int) -> Int {
        return (max(1, level) - 1) / PetConfig.affinityDialogueTierSize + 1
    }

    // MARK: - 한국어 대사 통합

    private static func koreanLines(for trigger: DialogueTrigger, level: Int) -> [String] {
        let currentTier = affinityDialogueTier(for: level)

        // Tier 1 기본 대사는 항상 포함
        var result = koreanBaseLines(for: trigger)

        // Tier 2 이상이면 해당 티어까지 누적 추가
        if currentTier >= 2 {
            for tier in 2...currentTier {
                result += koreanTierLines(for: trigger, tier: tier)
            }
        }

        return result
    }

    // MARK: - 한국어 기본 대사 (Tier 1 / Lv 1~5)
    // 처음 만난 사이처럼, 아직 서로 낯설고 어색한 단계

    private static func koreanBaseLines(for trigger: DialogueTrigger) -> [String] {
        switch trigger {

        case .idle:
            return [
                "저기... 안녕하세요.",
                "저.. 여기 있어요..!! 혹시 모르실까봐요..",
                "뭐.. 할 말이 있는데.. 아..없어요.",
            ]

        case .smile:
            return [
                "아.. 헤헤..",
                "ㄱ..감사합니다.. 어..",
                "ㅈ..좋은 것 같아요.. 아마도요.",
            ]

        case .boring:
            return [
                "...지루하네요.",
                "음.. 심심해요.",
                "뭔가 해야 할 것 같은데..",
            ]

        case .jumping:
            return [
                "아.. ㅅ..신나요..!",
                "점프..? ..해볼게요..!",
                "야호..?",
                "히히..?",
            ]

        case .touch:
            return [
                "앗..!?",
                "저...!!",
                "갑자기요..!?",
                "어..!?",
                "으앗..",
            ]

        case .workingStart:
            return [
                "아, 일 시작하는군요..",
                "저... 준비됐어요.",
                "ㅇ..열심히 하겠습니다..",
            ]

        case .working:
            return [
                "...",
                "저도 여기 있어요..",
                "ㅈ..집중하시는 거죠..?",
            ]

        case .workingEnd:
            return [
                "ㅅ..수고하셨어요..",
                "고생하셨어요.. 정말로요..",
            ]

        case .hungry:
            return [
                "저.. 배가 고픈데요..",
                "밥을.. 혹시.. 주실 수 있나요..",
                "꼬르륵.. 아, 들리셨나요..",
                "배가 고픈 것 같아요.. 저..",
                "힘이.. 조금.. 없어요..",
                "조금만 주셔도 되는데.. 어려우시면 괜찮아요..",
                "으.. 배고파요.. 말하기 좀 그렇지만..",
            ]

        case .fed:
            return [
                "아.. 감사해요..",
                "냠.. 맛있어요. 감사합니다.",
                "어.. 고마워요..!",
                "냠냠.. 아, 맛있네요.",
                "이거.. 맛있어요. 감사합니다.",
            ]
        }
    }

    // MARK: - 한국어 티어별 추가 대사

    /// tier 에 해당하는 추가 대사를 반환합니다.
    /// tier 1은 koreanBaseLines 가 담당하므로 여기서는 tier 2 이상만 정의합니다.
    private static func koreanTierLines(for trigger: DialogueTrigger, tier: Int) -> [String] {
        switch tier {

        // ─── Tier 2 (Lv 6~10) : 조금씩 친해지는 단계 ───────────────────────
        case 2:
            switch trigger {
            case .idle:
                return [
                    "같이 있어서 좋아요~",
                    "심심하지만 여기 있을게요!",
                ]
            case .smile:
                return [
                    "또 건드렸다~!",
                    "헤헤~ 좋아요!",
                ]
            case .boring:
                return [
                    "같이 놀면 안 되나요..?",
                    "지루해서 졸려요..",
                ]
            case .jumping:
                return [
                    "신이 난다~!",
                    "오늘 기분 좋은 거예요?!",
                ]
            case .touch:
                return [
                    "으앗!!",
                    "또..!?",
                ]
            case .workingStart:
                return [
                    "같이 열심히 해봐요!",
                    "파이팅이에요!!",
                ]
            case .working:
                return [
                    "조용히 응원하고 있어요..",
                    "열심히 하고 계시네요!",
                ]
            case .workingEnd:
                return [
                    "오늘도 수고하셨어요!",
                    "정말 열심히 하셨어요~!",
                ]
            case .hungry:
                return [
                    "배가 고파서 힘이 없어요...",
                    "조금만 주시면 안 될까요..?",
                ]
            case .fed:
                return [
                    "역시 당신이 주는 밥이 최고예요!!",
                    "맛있어요~ 감사해요!",
                ]
            }

        // ─── Tier 3 (Lv 11~15) : 친구가 된 단계 ─────────────────────────────
        case 3:
            switch trigger {
            case .idle:
                return [
                    "오늘 하루도 잘 부탁해요~!",
                    "같이 있어주셔서 감사해요~",
                ]
            case .smile:
                return [
                    "항상 이렇게 관심 줘서 고마워요~",
                    "히힛~",
                ]
            case .boring:
                return [
                    "뭔가 재미있는 일 없을까요~?",
                    "으으.. 지루해도 여기 있을게요",
                ]
            case .jumping:
                return [
                    "같이 신나요!! 히히~!",
                    "점프점프~!",
                ]
            case .touch:
                return [
                    "이제 그러려니 해요..",
                    "익숙해지고 있어요..!",
                ]
            case .workingStart:
                return [
                    "오늘도 최선을 다해봐요~!",
                    "응원하고 있을게요!",
                ]
            case .working:
                return [
                    "힘내세요~!",
                    "옆에서 지켜볼게요!",
                ]
            case .workingEnd:
                return [
                    "짱이에요~!! 수고하셨어요!",
                    "오늘도 완벽해요!!",
                ]
            case .hungry:
                return [
                    "배고파도 여기 있을게요.. 밥 주세요..",
                    "당신이 줄 때까지 기다릴게요..",
                ]
            case .fed:
                return [
                    "항상 이렇게 챙겨줘서 행복해요~!",
                    "냠냠~ 최고예요!!",
                ]
            }

        // ─── Tier 4 (Lv 16~20) : 절친이 된 단계 ─────────────────────────────
        case 4:
            switch trigger {
            case .idle:
                return [
                    "이렇게 매일 볼 수 있어서 행복해요!",
                    "당신이 없으면 심심할 것 같아요..",
                ]
            case .smile:
                return [
                    "당신이 제일 좋아요!",
                    "또 왔네요~ 기다렸어요!",
                ]
            case .boring:
                return [
                    "심심하지만 당신이 있어서 괜찮아요!",
                    "같이 있으니까 지루하지 않아요~",
                ]
            case .jumping:
                return [
                    "당신이 있으면 항상 신나요!!",
                    "최고야~!",
                ]
            case .touch:
                return [
                    "당신이라면 괜찮아요..!",
                    "헤헤.. 좋아요!",
                ]
            case .workingStart:
                return [
                    "당신이 일하는 모습 멋있어요~!",
                    "같이 열심히 해요!!",
                ]
            case .working:
                return [
                    "당신이 일하는 거 보면 저도 힘이 나요!",
                    "항상 응원해요~!",
                ]
            case .workingEnd:
                return [
                    "당신은 정말 대단해요!! 수고하셨어요!",
                    "항상 멋있어요!!",
                ]
            case .hungry:
                return [
                    "당신이 주는 밥이 제일 맛있어요.. 빨리 주세요..",
                    "배고파요.. 흑흑..",
                ]
            case .fed:
                return [
                    "당신이 줄 때가 제일 맛있어요!!",
                    "감사해요~ 당신이 최고예요!!",
                ]
            }

        // ─── Tier 5 (Lv 21~25) : 우리는 단짝 ────────────────────────────────
        case 5:
            switch trigger {
            case .idle:
                return [
                    "우리 오래오래 함께해요!!",
                    "매일 보고 싶어요~",
                ]
            case .smile:
                return [
                    "당신이 만져줄 때가 제일 행복해요~!",
                    "헤헤~ 역시 당신이에요!",
                ]
            case .boring:
                return [
                    "지루해도 당신 옆에 있는 게 좋아요!",
                    "같이 놀아요~!",
                ]
            case .jumping:
                return [
                    "우리 같이 신나요~!!",
                    "더 높이 점프할 수 있어요!!",
                ]
            case .touch:
                return [
                    "이제 기다리고 있어요..!",
                    "히히~ 왔다!",
                ]
            case .workingStart:
                return [
                    "언제나 응원해요!!",
                    "오늘도 잘 할 수 있어요!!",
                ]
            case .working:
                return [
                    "당신은 정말 대단해요!!",
                    "곁에 있을게요~!",
                ]
            case .workingEnd:
                return [
                    "최고예요!! 오늘도 수고하셨어요!!",
                    "역시 당신이에요!!",
                ]
            case .hungry:
                return [
                    "밥.. 주세요.. 당신이 주는 거면 다 맛있어요..",
                    "배고파서 쓰러질 것 같아요..",
                ]
            case .fed:
                return [
                    "이 맛은 당신이 주는 맛이에요~!! 냠냠!!",
                    "세상에서 제일 맛있어요!! 고마워요!!",
                ]
            }

        // ─── Tier 6+ : 추가 티어는 여기에 case 를 추가하세요 ─────────────────
        // case 6:
        //     ...

        default:
            // 정의되지 않은 티어는 빈 배열 반환 (기본 대사만 사용됨)
            return []
        }
    }
}
