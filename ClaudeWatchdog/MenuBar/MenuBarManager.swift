import AppKit
import SwiftUI
import Combine
import WidgetKit

/// 메뉴 바 상태 아이템 및 팝오버 관리
final class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    @Published var usage: ClaudeUsage = .empty
    @Published var error: String?
    @Published var isLoading = false
    @Published var credentialStatus: CredentialStatus = .unknown

    enum CredentialStatus: Equatable {
        case unknown
        case valid
        case notFound
        case expired
        case error(String)
    }

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        checkCredentials()
        startRefreshTimer()

        // 아이콘 스타일 변경 감지
        AppSettings.shared.$iconStyle
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        // 리프레시 간격 변경 감지
        AppSettings.shared.$refreshInterval
            .sink { [weak self] _ in self?.startRefreshTimer() }
            .store(in: &cancellables)
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.action = #selector(togglePopover)
        statusItem?.button?.target = self
        updateIcon()
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.animates = true

        let contentView = PopoverContentView(manager: self)
        popover.contentViewController = NSHostingController(rootView: contentView)

        self.popover = popover
    }

    // MARK: - Icon

    func updateIcon() {
        guard let button = statusItem?.button else { return }

        let style: MenuBarIconRenderer.Style
        switch AppSettings.shared.iconStyle {
        case .percentage: style = .percentage
        case .progressBar: style = .progressBar
        case .battery: style = .battery
        }

        if credentialStatus == .valid {
            button.image = MenuBarIconRenderer.createImage(
                percentage: usage.sessionPercentage,
                style: style
            )
        } else {
            button.image = MenuBarIconRenderer.createPlaceholderImage()
        }
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 팝오버 열 때 데이터 갱신
            refresh()
        }
    }

    // MARK: - Credentials

    func checkCredentials() {
        do {
            _ = try CredentialService.shared.getAccessToken()
            credentialStatus = .valid
        } catch let error as CredentialService.CredentialError {
            switch error {
            case .notFound:
                credentialStatus = .notFound
            case .tokenExpired:
                credentialStatus = .expired
            default:
                credentialStatus = .error(error.localizedDescription)
            }
        } catch {
            credentialStatus = .error(error.localizedDescription)
        }
        updateIcon()
    }

    // MARK: - Refresh

    func startRefreshTimer() {
        refreshTimer?.invalidate()
        let interval = AppSettings.shared.refreshInterval
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // 즉시 한 번 실행
        refresh()
    }

    func refresh() {
        guard credentialStatus == .valid else {
            checkCredentials()
            return
        }
        guard !isLoading else { return }

        isLoading = true
        error = nil

        Task { @MainActor in
            do {
                let previousPercentage = usage.sessionPercentage
                let newUsage = try await ClaudeAPIService.shared.fetchUsage()
                usage = newUsage
                error = nil

                // 위젯과 공유
                SharedUsageStore.shared.save(newUsage)
                WidgetCenter.shared.reloadAllTimelines()

                // 세션 리셋 감지 (이전 > 현재)
                if previousPercentage > newUsage.sessionPercentage + 10 {
                    NotificationService.shared.resetAlerts()
                }

                // 알림 확인
                NotificationService.shared.checkAndNotify(usage: newUsage)
            } catch {
                self.error = error.localizedDescription
                // 인증 에러면 크리덴셜 상태 갱신
                if error is CredentialService.CredentialError ||
                   (error as? ClaudeAPIService.APIError) == .unauthorized {
                    checkCredentials()
                }
            }

            isLoading = false
            updateIcon()
        }
    }
}

// Equatable for APIError
extension ClaudeAPIService.APIError: Equatable {
    static func == (lhs: ClaudeAPIService.APIError, rhs: ClaudeAPIService.APIError) -> Bool {
        switch (lhs, rhs) {
        case (.noCredentials, .noCredentials),
             (.unauthorized, .unauthorized),
             (.rateLimited, .rateLimited),
             (.parseFailed, .parseFailed):
            return true
        case (.serverError(let a), .serverError(let b)):
            return a == b
        default:
            return false
        }
    }
}
