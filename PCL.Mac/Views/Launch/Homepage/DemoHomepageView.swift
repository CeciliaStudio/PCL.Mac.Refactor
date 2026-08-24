//
//  DemoHomepageView.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/7/12.
//

import SwiftUI

struct DemoHomepageView: View {
    @StateObject private var loadingModel: MyLoadingViewModel = .init(text: "MyLoading 测试")
    @State private var selectedEntry: String = "下拉选择框"
    @State private var input: String = ""
    
    private let listItems: [ListItem] = [
        .init(name: "name1", description: "desc1"),
        .init(name: "name2", description: "desc2"),
        .init(name: "name3", description: "desc3"),
        .init(name: "name1", description: "desc1"),
        .init(name: "name2", description: "desc2"),
        .init(name: "name3", description: "desc3"),
        .init(name: "name1", description: "desc1"),
        .init(name: "name2", description: "desc2"),
        .init(name: "name3", description: "desc3"),
        .init(name: "name1", description: "desc1"),
        .init(name: "name2", description: "desc2"),
        .init(name: "name3", description: "desc3")
    ]
    private let entries = ["下拉选择框"] + Array(0..<10).map { "entry\($0)" }
    
    var body: some View {
        CardContainer {
            MyTip(text: "这是一个用于预览与测试控件的主页！", theme: .blue)
            MyCard("可折叠的卡片") {
                VStack {
                    MyText("文本")
                    HStack {
                        MyButton("普通按钮") {}
                        MyButton("高亮按钮", type: .highlight) {}
                        MyButton("红色按钮", type: .red) {}
                    }
                    .frame(height: 60)
                    HStack {
                        MyButton("普通按钮", subLabel: "但是两行文本") {}
                        MyButton("高亮按钮", subLabel: "但是两行文本", type: .highlight) {}
                        MyButton("红色按钮", subLabel: "但是两行文本", type: .red) {}
                    }
                    .frame(height: 60)
                    HStack {
                        MyButton("禁用按钮", subLabel: "灰色且不可点击", disabled: true) {}
                    }
                    .frame(height: 60)
                    MyList(items: listItems, selectable: true)
                }
            }
            MyCard("不可折叠的卡片", foldable: false) {
                MyText("该卡片默认展开")
            }
            .cardIndex(1)
            
            MyCard(nil) {
                MyText("不可折叠也没有标题的卡片")
            }
            .cardIndex(2)
            
            MyCard(nil) {
                HStack {
                    MyButton(".tasks") {
                        AppRouter.shared.append(.tasks)
                    }
                    .frame(width: 120)
                    
                    MyButton("弹窗") {
                        Task {
                            _ = await MessageBoxManager.shared.showTextAsync(
                                title: "普通弹窗",
                                content: "Hello, world!",
                                .init(id: 0, label: "hint（点击这个按钮不会关闭弹窗！）", type: .normal) {
                                    hint("awa!", type: .finish)
                                },
                                .yes(type: .highlight),
                            )
                            
                            let index: Int? = await MessageBoxManager.shared.showListAsync(title: "列表选择", items: listItems)
                            let text: String? = await MessageBoxManager.shared.showInputAsync(title: "文本输入", initialContent: "111", placeholder: "请输入文本")
                            if let index {
                                hint("你选择的是：\(listItems[index].name)", type: .finish)
                            }
                            if let text {
                                hint("你输入的是：\(text)", type: .finish)
                            }
                        }
                    }
                    .frame(width: 120)
                    
                    MyButton("错误弹窗", type: .red) {
                        MessageBoxManager.shared.showText(
                            title: "Minecraft 发生崩溃",
                            content: "你的游戏发生了一些问题，无法继续运行。\n很抱歉，PCL.Mac 暂时没有崩溃分析功能……\n\n若要寻求帮助，请点击“导出崩溃报告”并将导出的文件发给他人，而不是发送关于此页面的图片！！！",
                            level: .error
                        )
                    }
                    .frame(width: 120)
                }
                .frame(height: 40)
            }
            .cardIndex(3)
            
            MyLoading(viewModel: loadingModel)
                .cardIndex(4)
            
            MyCard("修改 MyLoading 状态", foldable: false) {
                HStack(spacing: 22) {
                    MyButton("fail()", type: .red) { loadingModel.fail(with: "加载失败") }
                        .frame(width: 120)
                    MyButton("reset()", type: .normal) { loadingModel.reset() }
                        .frame(width: 120)
                    Spacer()
                }
                .frame(height: 35)
            }
            .cardIndex(5)
            
            MyCard("弹出 hint", foldable: false) {
                HStack(spacing: 22) {
                    MyButton("info") { hint("这是一条 info 类型的 hint！", type: .info) }
                        .frame(width: 120)
                    MyButton("finish", type: .highlight) { hint("这是一条 finish 类型的 hint！", type: .finish) }
                        .frame(width: 120)
                    MyButton("critical", type: .red) { hint("这是一条 critical 类型的 hint！", type: .critical) }
                        .frame(width: 120)
                    Spacer()
                }
                .frame(height: 36)
            }
            .cardIndex(6)
            
            MyCard("其它控件", folded: false) {
                MySelect($selectedEntry, entries: entries)
                MyTextField(text: $input, placeholder: "文本输入框")
            }
        }
    }
}
