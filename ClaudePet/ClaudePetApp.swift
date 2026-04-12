import SwiftUI
import AppKit
import ApplicationServices
import Combine

@main
struct ClaudePetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private enum Layout {
        static let spriteScale: CGFloat         = 3.0
        static let baseSpriteSize: CGFloat      = 32.0
        static let bottomMargin: CGFloat        = -10.0   // ← 하단 여백 (음수 = 독 아래로 숨김)
        static let topEffectHeadroomRatio: CGFloat = 1.3
        static let counterHeight: CGFloat       = 32.0   // ← 타이핑 카운터 영역 높이 (px)

        // 대사 전용 패널 설정
        static let dialogueWidth: CGFloat       = 180.0   // ← 대사 박스 최대 너비 (px)
        static let dialogueHeight: CGFloat      = 0.0    // ← 대사 박스 높이 여유분 (px)
        static let dialogueGapAboveSprite: CGFloat = 6.0  // ← 스프라이트 상단과의 간격 (px)

        // 메뉴 HUD 높이 — PetConfig.debugEnabled 에 따라 자동 선택됩니다.
        static let hudHeightBase:  CGFloat = 160.0   // ← 디버그 OFF 시 HUD 높이 (px)
        static let hudHeightDebug: CGFloat = 328.0   // ← 디버그 ON  시 HUD 높이 (px)
        static var hudHeight: CGFloat {
            PetConfig.debugEnabled ? hudHeightDebug : hudHeightBase
        }
    }

    var overlayWindow: NSWindow?
    var dialoguePanel: NSPanel?
    var counterPanel:  NSPanel?

    // ─── 메뉴 HUD ─────────────────────────────────────────────────────────
    var menuHUDPanel:                  NSPanel?
    var menuOutsideClickMonitor:       Any?   // 다른 앱 클릭 감지 (global)
    var menuOutsideClickLocalMonitor:  Any?   // 앱 내부 클릭 감지 (local)

    // ─── 설정 HUD ─────────────────────────────────────────────────────────
    var settingsHUDPanel:                 NSPanel?
    var settingsOutsideClickMonitor:      Any?
    var settingsOutsideClickLocalMonitor: Any?

    // ─── 손쉬운 사용 권한 폴링 ──────────────────────────────────────────────
    private var accessibilityPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {

        // ─── 단일 인스턴스 확인 ──────────────────────────────────────────────
        // 동일한 Bundle ID 로 이미 실행 중인 인스턴스가 있으면
        // 그 인스턴스를 앞으로 가져오고 현재 프로세스를 즉시 종료합니다.
        let myBundleID = Bundle.main.bundleIdentifier ?? ""
        let existingInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: myBundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        if let existing = existingInstances.first {
            existing.activate(options: .activateIgnoringOtherApps)
            NSApp.terminate(nil)
            return
        }

        // ─── 손쉬운 사용 권한 확인 ────────────────────────────────────────────
        requestAccessibilityPermissionIfNeeded()

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        // ─── 스프라이트 메인 창 ───────────────────────────────────────────
        let spriteSize     = Layout.baseSpriteSize * SettingsManager.shared.spriteScale
        let effectHeadroom = spriteSize * Layout.topEffectHeadroomRatio
        let size           = CGSize(width: spriteSize, height: spriteSize + effectHeadroom)

        // 타이핑 카운터가 스프라이트와 겹쳐지므로 스프라이트를 화면 최하단에서 시작
        let origin = CGPoint(
            x: screen.visibleFrame.maxX - size.width,
            y: 0                                                                 // 화면 최하단 기준
        )

        let overlayWindow = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.overlayWindow = overlayWindow
        overlayWindow.backgroundColor = .clear
        overlayWindow.isOpaque = false
        overlayWindow.hasShadow = false
        overlayWindow.level = .floating
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        overlayWindow.contentView = NSHostingView(rootView: ContentView())
        overlayWindow.makeKeyAndOrderFront(nil)

        // ─── 대사 전용 플로팅 패널 (독립 레이어) ─────────────────────────
        //
        // • ignoresMouseEvents = true  → 클릭·드래그가 완전히 통과됩니다.
        // • addChildWindow             → 스프라이트 창이 걸어서 이동할 때
        //                               오프셋을 유지하며 자동으로 따라갑니다.
        //
        // 위치 계산:
        //   스프라이트 가시 상단 Y = bottomMargin + spriteSize
        //   패널 Y               = 스프라이트 상단 + dialogueGap
        //   패널 X               = 스프라이트 중심에서 패널 너비의 절반을 뺀 값 (수평 중앙 정렬)
        let uiScaleInit         = SettingsManager.shared.uiScale
        let diaWidth            = Layout.dialogueWidth * uiScaleInit
        let spriteVisibleTopY   = origin.y + spriteSize + Layout.dialogueGapAboveSprite * uiScaleInit
        let dialoguePanelX      = origin.x - (diaWidth - spriteSize) / 2

        let dialogueRect = NSRect(
            x: dialoguePanelX,
            y: spriteVisibleTopY,
            width: diaWidth,
            height: Layout.dialogueHeight
        )

        let panel = NSPanel(
            contentRect: dialogueRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.dialoguePanel = panel
        panel.backgroundColor      = .clear
        panel.isOpaque             = false
        panel.hasShadow            = false
        panel.level                = .floating
        panel.ignoresMouseEvents   = true
        panel.collectionBehavior   = [.canJoinAllSpaces, .stationary]
        panel.contentView          = NSHostingView(rootView: DialogueWindowContent())

        // 스프라이트 창의 자식으로 등록 → 이동 시 자동으로 함께 이동
        overlayWindow.addChildWindow(panel, ordered: .above)

        // ─── 타이핑 카운터 패널 (스프라이트 이미지 위에 겹쳐서 표시) ─────
        //
        // • 스프라이트 창과 동일한 x, y 위치 — 이미지와 겹침
        // • ignoresMouseEvents = true → 클릭이 완전히 통과됩니다
        // • addChildWindow           → 창 이동 시 스프라이트와 함께 이동
        // • level = overlayWindow.level + 1 → 항상 스프라이트보다 앞에 렌더링
        let counterRect = NSRect(
            x: origin.x,
            y: origin.y,                                                         // 스프라이트와 동일 위치 (겹침)
            width:  spriteSize,
            height: Layout.counterHeight * uiScaleInit
        )

        let counter = NSPanel(
            contentRect: counterRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.counterPanel = counter
        counter.backgroundColor    = .clear
        counter.isOpaque           = false
        counter.hasShadow          = false
        counter.level              = NSWindow.Level(rawValue: overlayWindow.level.rawValue + 1) // 스프라이트보다 위
        counter.ignoresMouseEvents = true
        counter.collectionBehavior = [.canJoinAllSpaces, .stationary]
        counter.contentView        = NSHostingView(rootView: CounterWindowContent())

        overlayWindow.addChildWindow(counter, ordered: .above)

        // ─── 메뉴 HUD 알림 등록 ───────────────────────────────────────────
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleMenuHUD),
            name: .claudePetToggleMenu,
            object: nil
        )

        // ─── 설정 HUD 알림 등록 ───────────────────────────────────────────
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleSettingsHUD),
            name: .claudePetOpenSettings,
            object: nil
        )

        // ─── 설정 변경 알림 등록 (배율 변경 즉시 적용) ────────────────────
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: SettingsManager.didChange,
            object: nil
        )

        // ─── 시작 시 저장된 배율 적용 ─────────────────────────────────────
        // (winodw 가 이미 만들어진 뒤에 호출)
        DispatchQueue.main.async { self.applyScale() }

        // ─── Sparkle 자동 업데이트 초기화 ────────────────────────────────
        // Sparkle 이 앱 시작 시 자동으로 업데이트를 확인하고 알림을 표시합니다.
        SparkleManager.shared.setup()
    }

    // MARK: - 메뉴 HUD 토글

    @objc private func handleToggleMenuHUD() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let panel = self.menuHUDPanel, panel.isVisible {
                self.hideMenuHUD()
            } else {
                self.showMenuHUD()
            }
        }
    }

    private func showMenuHUD() {
        ensureMenuHUDPanel()
        guard let panel = menuHUDPanel, let petWindow = overlayWindow else { return }

        let uiScale     = SettingsManager.shared.uiScale
        let spriteSize  = Layout.baseSpriteSize * SettingsManager.shared.spriteScale
        let hudWidth    = 188 * uiScale
        let hudHeight   = Layout.hudHeight * uiScale
        let screen = NSScreen.main ?? NSScreen.screens[0]

        // 펫 스프라이트 바로 위에 위치, 수평 중앙 정렬
        var hudX = petWindow.frame.midX - hudWidth / 2
        let hudY = petWindow.frame.origin.y + spriteSize + 6

        // 화면 경계 클램핑
        hudX = max(screen.frame.minX + 8, min(hudX, screen.frame.maxX - hudWidth - 8))

        panel.setFrame(NSRect(x: hudX, y: hudY, width: hudWidth, height: hudHeight), display: false)
        panel.alphaValue = 0
        panel.orderFront(nil)

        // 페이드 인
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }

        // 외부 클릭 시 닫기 감지 — 다른 앱 클릭 (global)
        if menuOutsideClickMonitor == nil {
            menuOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                guard let self,
                      let hudPanel = self.menuHUDPanel, hudPanel.isVisible
                else { return }
                let mousePos   = NSEvent.mouseLocation
                let insideHUD  = NSPointInRect(mousePos, hudPanel.frame)
                let insidePet  = self.overlayWindow.map { NSPointInRect(mousePos, $0.frame) } ?? false
                // 펫 위 클릭은 toggle 이 처리하므로 여기서는 무시
                if !insideHUD && !insidePet {
                    DispatchQueue.main.async { self.hideMenuHUD() }
                }
            }
        }

        // 외부 클릭 시 닫기 감지 — 앱 내부 클릭 (local)
        // addGlobalMonitorForEvents 는 다른 앱 이벤트만 감지하므로,
        // 같은 앱 내 오버레이 창 등을 클릭할 때도 HUD 를 닫으려면 로컬 모니터가 필요합니다.
        if menuOutsideClickLocalMonitor == nil {
            menuOutsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] event in
                guard let self,
                      let hudPanel = self.menuHUDPanel, hudPanel.isVisible
                else { return event }
                let mousePos  = NSEvent.mouseLocation
                let insideHUD = NSPointInRect(mousePos, hudPanel.frame)
                if !insideHUD {
                    DispatchQueue.main.async { self.hideMenuHUD() }
                }
                return event
            }
        }
    }

    private func hideMenuHUD() {
        guard let panel = menuHUDPanel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
        if let m = menuOutsideClickMonitor {
            NSEvent.removeMonitor(m)
            menuOutsideClickMonitor = nil
        }
        if let m = menuOutsideClickLocalMonitor {
            NSEvent.removeMonitor(m)
            menuOutsideClickLocalMonitor = nil
        }
    }

    // MARK: - 설정 HUD 토글

    @objc private func handleToggleSettingsHUD() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let panel = self.settingsHUDPanel, panel.isVisible {
                self.hideSettingsHUD()
            } else {
                self.showSettingsHUD()
            }
        }
    }

    @objc private func handleSettingsChanged() {
        DispatchQueue.main.async {
            // 배율이 바뀌면 HUD 패널을 파괴해 다음 open 시 새 크기로 재생성합니다.
            // 현재 패널이 열려 있으면 먼저 닫고 배율 적용 후 다시 엽니다.
            let menuWasVisible     = self.menuHUDPanel?.isVisible     ?? false
            let settingsWasVisible = self.settingsHUDPanel?.isVisible ?? false

            if menuWasVisible     { self.hideMenuHUD()     }
            if settingsWasVisible { self.hideSettingsHUD() }

            self.menuHUDPanel     = nil
            self.settingsHUDPanel = nil

            self.applyScale()

            if menuWasVisible     { self.showMenuHUD()     }
            if settingsWasVisible { self.showSettingsHUD() }
        }
    }

    private func showSettingsHUD() {
        ensureSettingsHUDPanel()
        guard let panel = settingsHUDPanel, let petWindow = overlayWindow else { return }

        let uiScale    = SettingsManager.shared.uiScale
        let spriteSize = Layout.baseSpriteSize * SettingsManager.shared.spriteScale
        let hudWidth   = 188 * uiScale
        let hudHeight  = 196 * uiScale    // 설정 HUD 기본 높이 × 배율 (업데이트 행 +48 포함)
        let screen = NSScreen.main ?? NSScreen.screens[0]

        var hudX = petWindow.frame.midX - hudWidth / 2
        let hudY = petWindow.frame.origin.y + spriteSize + 6

        hudX = max(screen.frame.minX + 8, min(hudX, screen.frame.maxX - hudWidth - 8))

        panel.setFrame(NSRect(x: hudX, y: hudY, width: hudWidth, height: hudHeight), display: false)
        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }

        // 외부 클릭 시 닫기 — global
        if settingsOutsideClickMonitor == nil {
            settingsOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                guard let self,
                      let hudPanel = self.settingsHUDPanel, hudPanel.isVisible
                else { return }
                let mousePos  = NSEvent.mouseLocation
                let insideHUD = NSPointInRect(mousePos, hudPanel.frame)
                let insidePet = self.overlayWindow.map { NSPointInRect(mousePos, $0.frame) } ?? false
                if !insideHUD && !insidePet {
                    DispatchQueue.main.async { self.hideSettingsHUD() }
                }
            }
        }

        // 외부 클릭 시 닫기 — local
        if settingsOutsideClickLocalMonitor == nil {
            settingsOutsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] event in
                guard let self,
                      let hudPanel = self.settingsHUDPanel, hudPanel.isVisible
                else { return event }
                let mousePos  = NSEvent.mouseLocation
                let insideHUD = NSPointInRect(mousePos, hudPanel.frame)
                if !insideHUD {
                    DispatchQueue.main.async { self.hideSettingsHUD() }
                }
                return event
            }
        }
    }

    private func hideSettingsHUD() {
        guard let panel = settingsHUDPanel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
        if let m = settingsOutsideClickMonitor {
            NSEvent.removeMonitor(m)
            settingsOutsideClickMonitor = nil
        }
        if let m = settingsOutsideClickLocalMonitor {
            NSEvent.removeMonitor(m)
            settingsOutsideClickLocalMonitor = nil
        }
    }

    private func ensureSettingsHUDPanel() {
        guard settingsHUDPanel == nil else { return }

        let uiScale = SettingsManager.shared.uiScale
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 188 * uiScale, height: 196 * uiScale),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.backgroundColor  = .clear
        panel.isOpaque         = false
        panel.hasShadow        = true
        panel.level            = NSWindow.Level(
            rawValue: (overlayWindow?.level.rawValue ?? NSWindow.Level.floating.rawValue) + 2
        )
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let effectView = NSVisualEffectView()
        effectView.material     = .popover
        effectView.blendingMode = .behindWindow
        effectView.state        = .active
        effectView.wantsLayer   = true

        let hostingView = NSHostingView(
            rootView: SettingsHUDView(
                onClose: { [weak self] in self?.hideSettingsHUD() }
            )
        )
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        effectView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
        ])
        panel.contentView = effectView
        settingsHUDPanel = panel
    }

    // MARK: - 배율 적용

    /// SettingsManager.spriteScale 에 따라 모든 패널의 크기·위치를 재계산합니다.
    private func applyScale() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let petWindow = overlayWindow else { return }

        let settings       = SettingsManager.shared
        let uiScale        = settings.uiScale
        let spriteSize     = Layout.baseSpriteSize * settings.spriteScale
        let effectHeadroom = spriteSize * Layout.topEffectHeadroomRatio
        let windowSize     = CGSize(width: spriteSize, height: spriteSize + effectHeadroom)

        let origin = CGPoint(
            x: screen.visibleFrame.maxX - windowSize.width,
            y: 0
        )

        // 스프라이트 메인 창
        petWindow.setFrame(NSRect(origin: origin, size: windowSize), display: true)

        // 타이핑 카운터 패널 — 높이도 배율에 맞게 스케일
        if let counter = counterPanel {
            let counterRect = NSRect(
                x: origin.x,
                y: origin.y,
                width:  spriteSize,
                height: Layout.counterHeight * uiScale
            )
            counter.setFrame(counterRect, display: true)
        }

        // 대사 패널 — 너비·간격도 배율에 맞게 스케일
        if let dialogue = dialoguePanel {
            let gap               = Layout.dialogueGapAboveSprite * uiScale
            let diaWidth          = Layout.dialogueWidth * uiScale
            let spriteVisibleTopY = origin.y + spriteSize + gap
            let dialoguePanelX    = origin.x - (diaWidth - spriteSize) / 2
            let dialogueRect = NSRect(
                x: dialoguePanelX,
                y: spriteVisibleTopY,
                width:  diaWidth,
                height: Layout.dialogueHeight
            )
            dialogue.setFrame(dialogueRect, display: true)
        }

        // 열려 있는 메뉴·설정 HUD 위치도 갱신 (패널 재생성 전이므로 위치만 이동)
        let hudBaseWidth: CGFloat = 188
        if let menuPanel = menuHUDPanel, menuPanel.isVisible {
            let hudWidth = hudBaseWidth * uiScale
            var hudX     = petWindow.frame.midX - hudWidth / 2
            hudX = max(screen.frame.minX + 8, min(hudX, screen.frame.maxX - hudWidth - 8))
            let hudY = petWindow.frame.origin.y + spriteSize + 6
            menuPanel.setFrame(
                NSRect(x: hudX, y: hudY, width: hudWidth, height: menuPanel.frame.height),
                display: true
            )
        }
        if let settPanel = settingsHUDPanel, settPanel.isVisible {
            let hudWidth = hudBaseWidth * uiScale
            var hudX     = petWindow.frame.midX - hudWidth / 2
            hudX = max(screen.frame.minX + 8, min(hudX, screen.frame.maxX - hudWidth - 8))
            let hudY = petWindow.frame.origin.y + spriteSize + 6
            settPanel.setFrame(
                NSRect(x: hudX, y: hudY, width: hudWidth, height: settPanel.frame.height),
                display: true
            )
        }
    }

    /// 최초 호출 시 한 번만 패널을 생성합니다. 이후 show/hide 로만 관리합니다.
    private func ensureMenuHUDPanel() {
        guard menuHUDPanel == nil else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 188 * SettingsManager.shared.uiScale,
                                            height: Layout.hudHeight * SettingsManager.shared.uiScale),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.backgroundColor  = .clear
        panel.isOpaque         = false
        panel.hasShadow        = true   // 시스템이 콘텐츠 형태에 맞는 그림자를 생성
        panel.level            = NSWindow.Level(
            rawValue: (overlayWindow?.level.rawValue ?? NSWindow.Level.floating.rawValue) + 2
        )
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // ── NSVisualEffectView 를 content view 로 직접 사용 ────────────────
        // SwiftUI .background() 안에 NSVisualEffectView 를 넣으면 다른 앱 위에서
        // blendingMode 가 제대로 동작하지 않아 직각 흰 배경이 보이는 문제가 발생합니다.
        // content view 자체를 NSVisualEffectView 로 설정하고 cornerRadius + masksToBounds 로
        // 정확히 둥근 모서리 클리핑을 처리합니다.
        let hudEffectView = NSVisualEffectView()
        hudEffectView.material      = .popover
        hudEffectView.blendingMode  = .behindWindow
        hudEffectView.state         = .active
        hudEffectView.wantsLayer    = true

        let hudHostingView = NSHostingView(
            rootView: MenuHUDView(
                onClose: { [weak self] in self?.hideMenuHUD() },
                onFeed:  { [weak self] in
                    guard let self else { return }
                    // 밥주기: HungerManager 소비 처리 후 대사 출력
                    let success = HungerManager.shared.feed()
                    if success {
                        // ContentView 의 AnimationController 에 fed 대사 전달
                        NotificationCenter.default.post(
                            name: .claudePetFed, object: nil
                        )
                    }
                }
            )
        )
        hudHostingView.wantsLayer = true
        hudHostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hudHostingView.translatesAutoresizingMaskIntoConstraints = false

        hudEffectView.addSubview(hudHostingView)
        NSLayoutConstraint.activate([
            hudHostingView.leadingAnchor.constraint(equalTo: hudEffectView.leadingAnchor),
            hudHostingView.trailingAnchor.constraint(equalTo: hudEffectView.trailingAnchor),
            hudHostingView.topAnchor.constraint(equalTo: hudEffectView.topAnchor),
            hudHostingView.bottomAnchor.constraint(equalTo: hudEffectView.bottomAnchor),
        ])
        panel.contentView = hudEffectView
        menuHUDPanel = panel
    }

    // MARK: - 손쉬운 사용 권한 요청

    /// 손쉬운 사용 권한이 없을 경우 안내 알림을 표시하고 시스템 설정을 엽니다.
    /// 권한이 부여될 때까지 1초 간격으로 폴링하며, 획득 시 노티피케이션을 발송합니다.
    private func requestAccessibilityPermissionIfNeeded() {
        // 이미 권한이 있으면 아무것도 하지 않음
        guard !AXIsProcessTrusted() else { return }

        // 시스템 팝업 트리거 (코드 서명된 배포 앱에서는 이것만으로도 팝업이 뜸)
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )

        // 안내 알림 표시 — 팝업이 뜨지 않는 환경(미서명 빌드 등)을 대비
        let alert = NSAlert()
        alert.messageText = "손쉬운 사용 권한이 필요합니다"
        alert.informativeText = """
            타이핑 카운터가 작동하려면 손쉬운 사용(접근성) 권한이 필요합니다.

            시스템 설정 > 개인 정보 보호 및 보안 > 손쉬운 사용
            에서 ClaudePet 항목을 활성화해 주세요.
            """
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }

        // 권한 획득될 때까지 폴링 (최대 5분)
        startAccessibilityPolling()
    }

    private func startAccessibilityPolling() {
        var elapsed = 0
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            elapsed += 1
            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.accessibilityPollTimer = nil
                // ContentView 의 startKeyboardMonitor() 를 트리거
                NotificationCenter.default.post(name: .accessibilityPermissionGranted, object: nil)
            } else if elapsed >= 300 {
                // 5분 후 포기
                timer.invalidate()
                self?.accessibilityPollTimer = nil
            }
        }
    }
}

// MARK: - 노티피케이션 이름 확장
extension Notification.Name {
    static let accessibilityPermissionGranted = Notification.Name("com.claudepet.accessibilityPermissionGranted")
}

// MARK: - 타이핑 카운트 공유 모델
//
// @AppStorage 는 별도 NSHostingView 간 변경 감지가 불안정하므로
// ObservableObject 싱글톤으로 두 뷰가 동일한 인스턴스를 직접 관찰합니다.

final class TypingCounter: ObservableObject {
    static let shared = TypingCounter()
    static let didChange = Notification.Name("TypingCounterDidChange")
    private static let key = "typingCount"

    @Published var count: Int = UserDefaults.standard.integer(forKey: key)

    func increment() {
        count += 1
        UserDefaults.standard.set(count, forKey: Self.key)
        // NSHostingView가 별도 창에 있을 때 @ObservedObject 갱신이 불안정하므로
        // NotificationCenter로 명시적 갱신 신호를 보냅니다.
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    /// 지정한 양만큼 카운터를 차감합니다.
    /// 0 미만으로 내려가지 않습니다.
    func consume(_ amount: Int) {
        count = max(0, count - amount)
        UserDefaults.standard.set(count, forKey: Self.key)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    /// 지정한 양만큼 카운터를 증가시킵니다.
    /// [DEBUG] 디버그 버튼용 — 실제 게임 로직에 사용하지 마세요.
    func debugAdd(_ amount: Int) {
        count += amount
        UserDefaults.standard.set(count, forKey: Self.key)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    private init() {}
}

// MARK: - 타이핑 카운터 패널 콘텐츠

struct CounterWindowContent: View {
    // @ObservedObject 대신 @State + NotificationCenter 사용
    // → 별도 NSHostingView(child panel)에서도 확실하게 UI가 갱신됩니다.
    @State private var count:   Int     = UserDefaults.standard.integer(forKey: "typingCount")
    @State private var uiScale: CGFloat = SettingsManager.shared.uiScale

    var body: some View {
        Text(count.formatted(.number))
            .font(.system(size: 9 * uiScale, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.85))
            .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 4 * uiScale)
            .padding(.vertical,   2 * uiScale)
            .background(
                RoundedRectangle(cornerRadius: 4 * uiScale)
                    .fill(Color.black.opacity(0.50))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onReceive(NotificationCenter.default.publisher(for: TypingCounter.didChange)) { _ in
                count = TypingCounter.shared.count
            }
            .onReceive(NotificationCenter.default.publisher(for: SettingsManager.didChange)) { _ in
                uiScale = SettingsManager.shared.uiScale
            }
    }
}
