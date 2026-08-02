//
//  LaunchSidebar.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/10.
//

import SwiftUI
import Core

struct LaunchSidebar: Sidebar {
    @StateObject private var instanceVM: InstanceViewModel
    @StateObject private var accountVM: AccountViewModel = .init()
    @StateObject private var launchVM: LaunchViewModel = .init()
    @State private var addingYggdrasilAccount: Bool = false
    
    init(instanceManager: InstanceManager) {
        self._instanceVM = StateObject(wrappedValue: InstanceViewModel(instanceManager: instanceManager))
    }
    
    let width: CGFloat = 285
    
    private let insertTransition: AnyTransition =
        .asymmetric(
            insertion: .modifier(
                active: ScaleOpacityEffect(scale: 0.95, opacity: 0.0),
                identity: ScaleOpacityEffect(scale: 1.0, opacity: 1.0)
            )
            .animation(.spring(response: 0.2)),
            removal: .opacity
        )
    
    var body: some View {
        if launchVM.isLaunching {
            launchingBody
        } else {
            normalBody
        }
    }
    
    private var normalBody: some View {
        VStack {
            Spacer()
            Group {
                switch accountVM.currentPanel {
                case .normal:
                    if let account = accountVM.currentAccount {
                        normalPanel(account)
                            .onTapGesture {
                                accountVM.currentPanel = .accountList
                            }
                    }
                case .accountList:
                    accountListPanel
                case .addYggdrasil:
                    addYggdrasilAccountPanel
                }
            }
            .transition(insertTransition)
            
            Spacer()
            VStack(spacing: 11) {
                Group {
                    if let instance = instanceVM.currentInstance {
                        MyButton("启动游戏", subLabel: instance.name, type: .highlight) {
                            guard !launchVM.isRunning && !launchVM.isLaunching else {
                                hint("已有一个游戏实例正在运行！", type: .critical)
                                return
                            }
                            if let account = accountVM.currentAccount {
                                launchVM.launch(instance, in: instanceVM.currentRepository, using: account)
                            } else {
                                hint("请先添加一个账号！", type: .critical)
                            }
                        }
                    } else {
                        MyButton("下载游戏", subLabel: "未找到可用的游戏实例", type: .normal) {
                            AppRouter.shared.setRoot(.download)
                        }
                    }
                }
                .frame(height: 50)
                HStack(spacing: 11) {
                    MyButton("实例选择") {
                        AppRouter.shared.append(.instanceList(repositoryId: instanceVM.currentRepository.id))
                    }
                    if let instance = instanceVM.currentInstance {
                        MyButton("实例设置") {
                            AppRouter.shared.append(.instanceSettings(id: instance.name))
                        }
                    }
                }
                .frame(height: 32)
            }
            .padding(21)
        }
        .onAppear {
            if instanceVM.currentRepository.instances == nil {
                instanceVM.reload(repository: instanceVM.currentRepository)
            }
        }
    }
    
    @ViewBuilder
    private func normalPanel(_ account: Account) -> some View {
        MyListItem {
            VStack(spacing: 15) {
                PlayerAvatar(account)
                VStack(spacing: 4) {
                    MyText(account.profile.name, size: 16)
                    MyText(account.localizedTypeName, size: 12, color: .colorGray4)
                }
            }
        }
        .fixedSize()
    }
    
    private var accountListPanel: some View {
        VStack {
            accountList
                .padding(.horizontal, 8)
            HStack {
                MyButton("添加账号") {
                    accountVM.requestAddAccount()
                }
                .frame(width: 80)
                
                if accountVM.currentAccount != nil {
                    MyButton("返回") {
                        accountVM.currentPanel = .normal
                    }
                    .frame(width: 50)
                }
            }
            .frame(height: 30)
        }
    }
    
    private var accountList: some View {
        VStack(spacing: 0) {
            ForEach(accountVM.accounts, id: \.id) { account in
                MyListItem { hovered in
                    HStack {
                        if account.id == accountVM.currentAccount?.id {
                            RightRoundedRectangle(cornerRadius: 4)
                                .fill(Color.color3)
                                .frame(width: 4, height: 20)
                                .offset(x: -4)
                        } else {
                            Spacer()
                                .frame(width: 12)
                        }
                        PlayerAvatar(account, length: 36)
                        VStack(alignment: .leading) {
                            MyText(account.profile.name)
                            MyText(account.localizedTypeName, color: .colorGray3)
                        }
                        Spacer()
                        if hovered {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12)
                                .foregroundStyle(Color.color3)
                                .padding(.trailing, 8)
                                .contentShape(.rect)
                                .onTapGesture {
                                    accountVM.remove(account: account)
                                    hint("移除成功！", type: .finish)
                                }
                        }
                    }
                }
                .onTapGesture {
                    accountVM.switchAccount(to: account)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: accountVM.currentAccount?.id)
    }
    
    private var addYggdrasilAccountPanel: some View {
        VStack {
            fieldLine("服务器") {
                MyTextField(text: $accountVM.yggdrasilServer)
            }
            fieldLine("用户名") {
                MyTextField(text: $accountVM.yggdrasilUsername)
            }
            fieldLine("密码") {
                MyTextField(text: $accountVM.yggdrasilPassword, secure: true)
            }
            HStack {
                MyButton("返回") {
                    accountVM.currentPanel = .accountList
                }
                .frame(width: 50)
                MyButton("登录", type: .highlight) {
                    guard !addingYggdrasilAccount else { return }
                    addingYggdrasilAccount = true
                    Task {
                        await accountVM.addYggdrasilAccount()
                        await MainActor.run {
                            addingYggdrasilAccount = false
                        }
                    }
                }
                .frame(width: 50)
            }
            .frame(height: 30)
            .padding(.top, 4)
        }
    }
    
    private var launchingBody: some View {
        VStack(spacing: 0) {
            Spacer()
            MyLoading(viewModel: launchVM.loadingViewModel, showCard: false)
            if let instanceName = launchVM.instanceName {
                MyText(instanceName, size: 13.5, color: .color3)
                    .padding(.top, 5)
            }
            HStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(stops: [
                            .init(color: Color.color4, location: 0),
                            .init(color: Color.color3, location: 0.6)
                        ], startPoint: .topLeading, endPoint: .topTrailing)
                    )
                    .frame(width: 225 * launchVM.progress)
                Rectangle()
                    .fill(Color.color6)
                    .opacity(0.6)
            }
            .frame(width: 225, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 27)
            
            // PanLaunchingInfo
            VStack(alignment: .leading) {
                if let currentStage: String = launchVM.currentStage {
                    launchingInfo(name: "当前步骤", value: currentStage)
                }
                launchingInfo(name: "启动进度") {
                    AnimatablePercentText(progress: launchVM.progress)
                }
            }
            
            // PanLaunchingHint
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.colorGray1, lineWidth: 1)
                    .padding(1)
                HStack {
                    MyText("你知道吗", size: 12.5)
                        .opacity(0.5)
                        .padding(.horizontal, 10)
                        .background(.white)
                        .offset(y: -8)
                }
                MyText("这是一段测试用的小提示文本，它应该足够长以让它有两行。", size: 12.5)
                    .padding(11)
            }
            .frame(width: 260, height: launchVM.isRunning ? nil : 0)
            .opacity(launchVM.isRunning ? 1 : 0)
            .padding(.top, 26)
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            MyButton("取消", launchVM.cancel)
                .frame(height: 32)
                .padding(21)
        }
        .animation(.easeOut(duration: 0.2), value: launchVM.progress)
        .animation(.easeOut(duration: 0.1), value: launchVM.isRunning)
    }
    
    @ViewBuilder
    private func launchingInfo(name: String, value: String) -> some View {
        launchingInfo(name: name) { MyText(value, size: 12.5) }
    }
    
    @ViewBuilder
    private func launchingInfo(name: String, value: () -> some View) -> some View {
        HStack(spacing: 15) {
            MyText(name, size: 12.5)
                .opacity(0.5)
            value()
        }
    }
    
    @ViewBuilder
    private func fieldLine(_ name: String, content: () -> some View) -> some View {
        HStack(spacing: 0) {
            MyText(name)
                .frame(width: 50, alignment: .leading)
            content()
        }
        .padding(.horizontal)
    }
}

private struct AnimatablePercentText: View, Animatable {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        let clamped: Double = min(max(progress, 0), 1)
        MyText(String(format: "%.2f %%", clamped * 100), size: 12.5)
    }
}

private struct ScaleOpacityEffect: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
    }
}
