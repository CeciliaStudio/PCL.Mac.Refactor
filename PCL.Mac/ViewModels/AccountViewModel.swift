//
//  AccountViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/1/15.
//

import SwiftUI
import Combine
import Core
import SwiftyJSON

class AccountViewModel: ObservableObject {
    @Published public private(set) var accounts: [Account] = [] {
        didSet {
            LauncherConfig.shared.accounts = accounts
        }
    }
    @Published public private(set) var currentAccountId: UUID? {
        didSet {
            LauncherConfig.shared.currentAccountId = currentAccountId
        }
    }
    public var currentAccount: Account? {
        if let currentAccountId {
            return accounts.first(where: { $0.id == currentAccountId })
        }
        return nil
    }
    
    @Published public var currentPanel: PanelType = .normal
    @Published public var yggdrasilServer: String = ""
    @Published public var yggdrasilUsername: String = ""
    @Published public var yggdrasilPassword: String = ""
    
    public init() {
        self.accounts = LauncherConfig.shared.accounts
        self.currentAccountId = LauncherConfig.shared.currentAccountId
        self.currentPanel = self.currentAccount == nil ? .accountList : .normal
    }
    
    /// 请求用户添加账号。
    public func requestAddAccount() {
        Task { @MainActor in
            log("正在请求添加账号")
            guard let idx: Int = await MessageBoxManager.shared.showListAsync(
                title: "添加账号 - 选择验证类型",
                items: [
                    .init(image: .iconMicrosoftAccount, imageSize: 32, name: "正版验证", description: nil),
                    .init(image: .iconThirdpartyAccount, imageSize: 32, name: "第三方验证", description: nil),
                    .init(image: .iconOfflineAccount, imageSize: 32, name: "离线验证", description: nil)
                ]
            ) else {
                return
            }
            if idx == 0 {
                await requestAddMicrosoftAccount()
            } else if idx == 1 {
                currentPanel = .addYggdrasil
            } else {
                await requestAddOfflineAccount()
            }
        }
    }
    
    /// 切换当前账号。
    public func switchAccount(to account: Account) {
        currentAccountId = account.id
    }
    
    /// 移除账号。
    /// - Parameter account: 要移除的账号。
    public func remove(account: Account) {
        accounts.removeAll(where: { $0.id == account.id })
        if currentAccount == nil {
            if let firstAccount = accounts.first {
                switchAccount(to: firstAccount)
            } else {
                currentAccountId = nil
            }
        }
    }
    
    /// 获取账号皮肤数据。
    public func skinData(for account: Account) async -> Data {
        let defaultSkin: Data = .init(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAMAAACdt4HsAAAAdVBMVEUAAAAKvLwAzMwmGgokGAgrHg0zJBE/KhW3g2uzeV5SPYn///+qclmbY0mQWT8Af38AaGhVVVWUYD52SzOBUzmPXj5JJRBCHQp3QjVqQDA0JRIoKCg3Nzc/Pz9KSko6MYlBNZtGOqUDenoFiIgElZUApKQAr6/wvakZAAAAAXRSTlMAQObYZgAAAolJREFUeNrt1l1rHucZReFrj/whu5hSCCQtlOTE/f+/Jz4q9Cu0YIhLcFVpVg+FsOCVehi8jmZgWOzZz33DM4CXlum3gH95GgeAzQZVeL4gTm6Cbp4vqFkD8HwBazPY8wWbMq9utu3mNZ5fotVezbzOE3kBEFbaZuc8kb00NTMUbWJp678Xf2GV7RRtx1TDQQ6XBNvsmL2+2vHq1TftmMPIyAWujtN2cl274ua2jpVpZneXEjjo7XW1q53V9ds4ODO5xIuhvGHvfLI3aixauig415uuO2+vl9+cncfsFw25zL650fXn687jqnXuP68/X3+eV3zE7y6u9eB73MlfAcfbTf3yR8CfAX+if8S/H5/EAbAxj5LN48tULvEBOh8V1AageMTXe2YHAOwHbZxrzPkSR3+ffr8TR2JDzE/4Fj8CDgEwDsW+q+9GsR07hhg2CsALBgMo2v5wNxXnQXMeGQVW7gUAyKI2m6KDsJ8Au3++F5RZO+kKNQjQcLLWgjwUjBXLltFgWWMUUlviocBgNoxNGgMjSxiYAA7zgLFo2hgIENiDU8gQCzDOmViGFAsEuBcQSDCothhpJaDRA8E5fHqH2nTbYm5fHLo1V0u3B7DAuheoeScRYabjjjuzs17cHVaTrTXmK78m9swP34d9oK/dfeXSIH2PW/MXwPvxN/bJlxw8zlYAcEyeI6gNgA/O8P8neN8xe1IHP2gTzegjvhUDfuRygmwEs2GE4mkCDIAzm2R4yAuPsIdR9k8AvMc+3L9+2UEjo4WP0FpgP19O0MzCsqxIoMsdDBvYcQyGmO0ZJRoYCKjLJWY0BAhYwGUBCgkh8MRdOKt+ruqMwAB2OcEX94U1TPbYJP0PkyyAI1S6cSIAAAAASUVORK5CYII=")!
        do {
            guard let textures: Data = account.profile.property(forName: "textures")
                .flatMap({ Data(base64Encoded: $0) }) else {
                return defaultSkin
            }
            let json: JSON = try .init(data: textures)
            guard let url: URL = json["textures"]["SKIN"]["url"].url else {
                err("解析 textures 属性失败")
                return defaultSkin
            }
            return try await HTTPClient.shared.get(url).data
        } catch {
            err("获取皮肤数据失败：\(error.localizedDescription)")
            return defaultSkin
        }
    }
    
    private func requestAddMicrosoftAccount() async {
        let service: MicrosoftAuthService = .init()
        let code: MicrosoftAuthService.AuthorizationCode
        log("开始进行微软登录")
        do {
            code = try await service.start()
            log("获取设备码成功")
        } catch {
            err("添加正版账号失败：获取设备码失败：\(error.localizedDescription)")
            hint("添加正版账号失败：获取设备码失败：\(error.localizedDescription)", type: .critical)
            return
        }
        
        let authTask = Task {
            do {
                guard let pollCount = service.pollCount,
                      let pollInterval = service.pollInterval else {
                    err("pollCount 或 pollInterval 未被设置")
                    throw MicrosoftAuthService.Error.internalError
                }
                do {
                    defer {
                        DispatchQueue.main.async {
                            NSApplication.shared.activate(ignoringOtherApps: true)
                            MessageBoxManager.shared.complete(with: .button(id: 1))
                        }
                    }
                    for i in 0..<pollCount {
                        try Task.checkCancellation()
                        log("第 \(i + 1)/\(pollCount) 次轮询")
                        try await Task.sleep(seconds: Double(pollInterval))
                        if try await service.poll() {
                            log("用户完成了授权")
                            break
                        }
                        if i == pollCount - 1 {
                            throw SimpleError("授权超时。")
                        }
                    }
                }
                hint("授权成功！正在完成后续登录步骤……")
                let response = try await service.authenticate()
                let account: MicrosoftAccount = .init(profile: response.profile, accessToken: response.accessToken, refreshToken: response.refreshToken)
                log("添加正版账号成功")
                hint("账号添加成功！", type: .finish)
                await MainActor.run {
                    LauncherConfig.shared.hasMicrosoftAccount = true
                    addAccount(account)
                }
            } catch let error where error.isCancellationError {
            } catch let error as MicrosoftAuthService.Error {
                switch error {
                case .xboxAuthenticationFailed(let code):
                    switch code {
                    case 2148916238:
                        showErrorMessageBox(
                            "Xbox 验证失败",
                            "当前账户为未成年账户，无法通过 Xbox Live 认证。\n请点击下方的“确定”按钮，更改账户年龄后再次尝试登录。",
                            "https://support.microsoft.com/account-billing/837badbc-999e-54d2-2617-d19206b9540a"
                        )
                    case 2148916233:
                        showErrorMessageBox(
                            "Xbox 验证失败",
                            "该微软账户没有关联 Xbox 账户。\n请点击下方的“确定”按钮，关联 Xbox 账户后再次尝试登录。",
                            "https://www.minecraft.net/msaprofile/mygames/editprofile"
                        )
                    default:
                        MessageBoxManager.shared.showText(
                            title: "Xbox 验证失败",
                            content: "发生未知错误。错误代码：\(code)",
                            level: .error
                        )
                    }
                case .apiError(let description):
                    MessageBoxManager.shared.showText(
                        title: "添加正版账号失败",
                        content: "响应体：\(description)",
                        level: .error
                    )
                case .internalError:
                    MessageBoxManager.shared.showText(
                        title: "添加正版账号失败",
                        content: "发生内部错误。\n若要寻求帮助，请将完整日志发送给他人，而不是发送此页面相关的图片。",
                        level: .error
                    )
                case .notPurchased:
                    showErrorMessageBox(
                        "添加正版账号失败",
                        "看起来你还没有购买 Minecraft。\n如果你已购买 Minecraft，请点击下方的“确定”按钮，创建档案后再次尝试登录。",
                        "https://www.minecraft.net/msaprofile/mygames/editprofile"
                    )
                }
            } catch {
                MessageBoxManager.shared.showText(
                    title: "添加正版账号失败",
                    content: "\(error.localizedDescription)\n若要寻求帮助，请将完整日志发送给他人，而不是发送此页面相关的图片。"
                )
                hint("登录失败：\(error.localizedDescription)", type: .critical)
            }
        }
        
        if await MessageBoxManager.shared.showTextAsync(
            title: "添加正版账号",
            content: "请打开 \(code.verificationURL)，然后输入 \(code.code)，随后根据提示完成后续授权步骤。\n点击下方按钮可以一键复制并跳转！",
            .init(id: 1, label: "复制并跳转", type: .highlight) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code.code, forType: .string)
                NSWorkspace.shared.open(code.verificationURL)
            },
            .no()
        ) == 0 {
            log("用户取消了授权")
            authTask.cancel()
        }
    }
    
    private func showErrorMessageBox(_ title: String, _ content: String, _ link: String) {
        MessageBoxManager.shared.showText(
            title: title,
            content: content,
            level: .error,
            .no(),
            .yes(type: .highlight)
        ) { result in
            if result == 1 {
                NSWorkspace.shared.open(link.url!)
            }
        }
    }
    
    public func addYggdrasilAccount() async {
        let trimmedServerLocation = yggdrasilServer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var authServerURL = URL(string: trimmedServerLocation) else {
            hint("验证服务器地址错误！", type: .critical)
            return
        }
        if let scheme: String = authServerURL.scheme {
            guard scheme == "https" || scheme == "http" else {
                hint("服务器地址无效！", type: .critical)
                return
            }
        } else {
            guard let newURL = URL(string: "https://\(trimmedServerLocation)") else {
                hint("服务器地址无效！", type: .critical)
                return
            }
            authServerURL = newURL
        }
        let username: String = yggdrasilUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let password: String = yggdrasilPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty && !password.isEmpty else {
            hint("用户名与密码不能为空！", type: .critical)
            return
        }
        let service: YggdrasilService = .init(authServerURL: authServerURL)
        do {
            let resolvedServerURL = try await service.resolveALI()
            if authServerURL != resolvedServerURL {
                log("解析 ALI 头成功，真实 API 地址：\(resolvedServerURL)")
                authServerURL = resolvedServerURL
            }
            log("正在验证，服务器地址：\(authServerURL)")
            let authResponse = try await service.authenticate(username, password: password)
            log("验证成功")
            
            let profile: PlayerProfile
            if let selectedProfile = authResponse.selectedProfile {
                profile = selectedProfile
            } else if authResponse.availableProfiles.isEmpty {
                hint("错误：这个账号中没有角色！", type: .critical)
                return
            } else {
                guard let idx = await MessageBoxManager.shared.showListAsync(
                    title: "选择角色",
                    items: authResponse.availableProfiles.map { ListItem(name: $0.name, description: UUIDUtils.string(of: $0.id, withHyphens: true)) }
                ) else { return }
                profile = authResponse.availableProfiles[idx]
            }
            // 获取带有角色属性的 PlayerProfile
            let fullProfile: PlayerProfile = try await service.fullProfile(for: profile.id)
            let serverMetadata = try await service.fetchMetadata()
            let account: YggdrasilAccount = .init(
                profile: fullProfile,
                authServer: serverMetadata.serverName ?? authServerURL.host ?? "未知",
                authServerURL: authServerURL,
                accessToken: authResponse.accessToken,
                clientToken: authResponse.clientToken
            )
            log("添加第三方账号（\(account.authServer)）成功：\(fullProfile.name)")
            await MainActor.run {
                addAccount(account)
                hint("添加成功！", type: .finish)
                currentPanel = .accountList
                yggdrasilServer = ""
                yggdrasilUsername = ""
                yggdrasilPassword = ""
            }
        } catch {
            log("添加第三方账号失败：\(error.localizedDescription)")
            MessageBoxManager.shared.showText(
                title: "添加第三方账号失败",
                content: "在验证时发生错误：\(error.localizedDescription)",
                level: .error,
                .yes()
            )
        }
    }
    
    private func requestAddOfflineAccount() async {
        guard let playerName: String = await MessageBoxManager.shared.showInputAsync(title: "玩家名") else {
            log("用户取消了添加")
            return
        }
        await MainActor.run {
            addAccount(OfflineAccount(name: playerName, uuid: UUIDUtils.uuid(ofOfflinePlayer: playerName)))
        }
    }
    
    private func addAccount(_ account: Account) {
        accounts.append(account)
        switchAccount(to: account)
    }
    
    enum PanelType {
        case normal, accountList, addYggdrasil
    }
}
