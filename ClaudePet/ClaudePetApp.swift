import SwiftUI
import AppKit

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

        // 대사 전용 패널 설정
        static let dialogueWidth: CGFloat       = 180.0   // ← 대사 박스 최대 너비 (px)
        static let dialogueHeight: CGFloat      = 0.0    // ← 대사 박스 높이 여유분 (px)
        static let dialogueGapAboveSprite: CGFloat = 6.0  // ← 스프라이트 상단과의 간격 (px)
    }

    var overlayWindow: NSWindow?
    var dialoguePanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        // ─── 스프라이트 메인 창 ───────────────────────────────────────────
        let spriteSize     = Layout.baseSpriteSize * Layout.spriteScale          // 96 px
        let effectHeadroom = spriteSize * Layout.topEffectHeadroomRatio          // ~124.8 px
        let size           = CGSize(width: spriteSize, height: spriteSize + effectHeadroom)

        let origin = CGPoint(
            x: screen.visibleFrame.maxX - size.width,
            y: Layout.bottomMargin
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
        let spriteVisibleTopY   = origin.y + spriteSize + Layout.dialogueGapAboveSprite
        let dialoguePanelX      = origin.x - (Layout.dialogueWidth - spriteSize) / 2

        let dialogueRect = NSRect(
            x: dialoguePanelX,
            y: spriteVisibleTopY,
            width: Layout.dialogueWidth,
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
    }
}
