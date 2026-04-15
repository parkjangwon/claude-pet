import Sparkle
import AppKit
import Combine
import os.log

/// Sparkle 자동 업데이트를 관리하는 싱글톤.
/// AppDelegate 초기화 시 setup() 을 한 번 호출하세요.
final class SparkleManager: NSObject, ObservableObject {
    static let shared = SparkleManager()

    @Published private(set) var isUpdateAvailable = false
    @Published private(set) var availableVersion: String?

    private let targetVersion = "1.0.18"
    private var updaterController: SPUStandardUpdaterController?
    private let log = Logger(subsystem: "com.cchh494.ClaudePet", category: "Sparkle")

    /// checkForUpdates() 가 명시적으로 호출됐는지 여부.
    /// 백그라운드 자동 체크와 사용자 트리거를 구분하기 위함.
    private var isUserInitiatedCheck = false

    private override init() {}

    /// AppDelegate.applicationDidFinishLaunching 에서 호출합니다.
    func setup() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        log.info("Sparkle updater initialized")
    }

    /// 업데이트 확인 버튼에서 호출합니다.
    /// Sparkle 이 자체 UI 다이얼로그를 표시합니다.
    func checkForUpdates() {
        isUserInitiatedCheck = true
        updaterController?.checkForUpdates(nil)
    }

    private func updateAvailability(for version: String?) {
        let hasTargetUpdate = version.map { isVersion($0, atLeast: targetVersion) } ?? false

        DispatchQueue.main.async {
            self.availableVersion = hasTargetUpdate ? version : nil
            self.isUpdateAvailable = hasTargetUpdate
        }
    }

    private func isVersion(_ version: String, atLeast target: String) -> Bool {
        version.compare(target, options: .numeric) != .orderedAscending
    }
}

// MARK: - SPUUpdaterDelegate
extension SparkleManager: SPUUpdaterDelegate {

    func feedURLString(for updater: SPUUpdater) -> String? {
        return "https://cchh494.github.io/claude-pet/appcast.xml"
    }

    // MARK: 에러 처리

    /// 업데이트 프로세스가 오류로 중단될 때 호출됩니다.
    /// 네트워크 오류, 서명 검증 실패, 다운로드 실패 등이 여기로 들어옵니다.
    ///
    /// 주의: "업데이트 없음" 도 Sparkle 내부적으로는 에러 코드로 전달되므로,
    /// 실제 오류만 필터링해서 처리합니다.
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let ns = error as NSError
        log.error("Update aborted — domain: \(ns.domain, privacy: .public), code: \(ns.code), desc: \(ns.localizedDescription, privacy: .public)")

        defer { isUserInitiatedCheck = false }

        // 사용자가 직접 체크한 경우에만 알림을 띄움
        guard isUserInitiatedCheck else { return }

        // "업데이트 없음", "사용자가 취소함" 은 진짜 오류가 아니므로 무시.
        // Sparkle 이 자체 다이얼로그를 이미 보여줬거나, 조용히 끝나야 하는 경우.
        if isBenignError(ns) { return }

        let (title, message) = friendlyMessage(for: ns)
        showAlert(title: title, message: message, style: .warning)
    }

    /// 실제 오류가 아닌 정상 종료 케이스를 구분.
    private func isBenignError(_ error: NSError) -> Bool {
        // SUErrorDomain 의 주요 정상 종료 코드:
        //   1001 SUNoUpdateError        — 업데이트 없음 (최신 상태)
        //   1002 SUAppcastError          — appcast 파싱 오류 (이건 실제 오류)
        //   4005 SUUserInitiatedCanceled — 사용자가 취소
        // NSUserCancelled 도 취소 케이스.
        if error.code == NSUserCancelledError { return true }

        let benignCodes: Set<Int> = [1001, 4005]
        if (error.domain == "SUSparkleErrorDomain" || error.domain == "SUErrorDomain")
            && benignCodes.contains(error.code) {
            return true
        }
        return false
    }

    /// 업데이트가 없을 때 호출됩니다. (에러 아님)
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        log.info("No update available")
        updateAvailability(for: nil)
        // Sparkle 이 기본 다이얼로그를 띄우므로 별도 처리 불필요
    }

    /// Sparkle 이 검증한 새 업데이트가 있을 때 호출됩니다.
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        log.info("Update available: v\(item.displayVersionString, privacy: .public)")
        updateAvailability(for: item.displayVersionString)
    }

    /// 다운로드 실패 시 호출됩니다.
    func updater(_ updater: SPUUpdater,
                 failedToDownloadUpdate item: SUAppcastItem,
                 error: Error) {
        log.error("Download failed for v\(item.displayVersionString, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Helpers

    /// NSError 를 사용자 친화적 메시지로 변환.
    private func friendlyMessage(for error: NSError) -> (title: String, message: String) {
        // SUErrorDomain — Sparkle 에러 도메인
        // NSURLErrorDomain — 네트워크 에러
        switch error.domain {
        case NSURLErrorDomain:
            switch error.code {
            case NSURLErrorNotConnectedToInternet:
                return ("인터넷 연결 없음",
                        "인터넷에 연결되어 있지 않아요.\n연결 상태를 확인한 뒤 다시 시도해주세요.")
            case NSURLErrorTimedOut:
                return ("요청 시간 초과",
                        "업데이트 서버 응답이 늦어지고 있어요.\n잠시 후 다시 시도해주세요.")
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                return ("서버 연결 실패",
                        "업데이트 서버에 연결할 수 없어요.\n잠시 후 다시 시도해주세요.")
            default:
                return ("네트워크 오류",
                        "업데이트 확인 중 네트워크 오류가 발생했어요.\n\n\(error.localizedDescription)")
            }

        case "SUSparkleErrorDomain", "SUErrorDomain":
            // 대표적인 코드: 4001 = 서명 불일치, 2000 = appcast 파싱 실패
            return ("업데이트 오류",
                    "업데이트 파일을 처리하지 못했어요.\n\n\(error.localizedDescription)\n\n잠시 후 다시 시도해도 해결되지 않으면 개발자에게 문의해주세요.")

        default:
            return ("업데이트 실패",
                    "\(error.localizedDescription)")
        }
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = style
            alert.addButton(withTitle: "확인")
            alert.runModal()
        }
    }
}
