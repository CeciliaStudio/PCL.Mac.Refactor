# PR: 修复正版账户认证失效时的错误提示

## 问题

当正版账户的登录状态过期后，用户尝试更换披风时会看到无意义的错误提示：

```
更换披风失败：未能完成操作。（Core.MicrosoftAuthService.Error错误1。）
```

根因是 `MicrosoftAuthService.Error` 没有实现 `LocalizedError` 协议，导致 `error.localizedDescription` 返回的是 Swift 默认的类型名字符串，而非有意义的描述。此外，代码无法区分"refresh token 永久过期（需要重新登录）"和"临时网络故障（可以重试）"两种不同的失败场景。

## 修改内容

### 1. `MicrosoftAuthService.Error` 实现 `LocalizedError`（Core 层）

**文件**: `PCL.Mac.Core/Services/MicrosoftAuthService.swift`

- `Error` 枚举新增 `LocalizedError` 和 `Equatable` 协议遵循
- 实现 `errorDescription` 计算属性，为每个 case 提供中文描述
- 新增 `invalidGrant` case，专门表示 OAuth refresh token 已过期或被吊销

这样所有调用方（披风选择、游戏启动、登录流程）都能通过 `error.localizedDescription` 获得可读的错误信息。

### 2. `post()` 方法识别 `invalid_grant`（Core 层）

**文件**: `PCL.Mac.Core/Services/MicrosoftAuthService.swift`

- 在 `post()` 方法中，当微软返回 `error == "invalid_grant"` 时，抛出 `.invalidGrant` 而非通用的 `.apiError`
- 这使得上层可以精确区分"需要重新登录"与"普通 API 错误"

### 3. 披风选择错误处理（App 层）

**文件**: `PCL.Mac/Views/Launch/CapeSelection.swift`

- catch 块新增对 `.invalidGrant` 的专门处理
- refresh token 过期时提示"正版账户登录状态已失效，请重新登录正版账户后再试"
- 其他错误现在也能正确显示中文描述（因为 `LocalizedError` 已实现）

### 4. 游戏启动刷新令牌错误处理（App 层）

**文件**: `PCL.Mac/Task/MinecraftLaunchTask.swift`

- `refreshAccount` 方法的 catch 块新增对 `.invalidGrant` 的专门处理
- refresh token 过期时不再提供"继续启动"选项（因为旧 token 已失效，继续也无法加入需要验证的服务器）
- 改为明确提示用户需要重新登录，并取消启动

### 5. 登录流程补全 exhaustive switch（App 层）

**文件**: `PCL.Mac/ViewModels/AccountViewModel.swift`

- `requestAddMicrosoftAccount` 的 switch 补全 `.invalidGrant` case
- 登录流程中理论上不会出现此错误（登录用的是 device_code 而非 refresh_token），仅为满足编译器的 exhaustive switch 要求

## 不涉及的部分

- 不修改登录流程本身（start/poll/authenticate 逻辑完全不变）
- 不修改刷新流程本身（refresh 的 API 调用链完全不变）
- 不新增设置项或 UI 变更
- 不引入披风缓存机制

## 测试

- 现有单元测试全部通过（9 个 test case）
- Debug 构建成功
- 已通过 curl 验证：过期 refresh token 确实返回 `invalid_grant`（AADSTS70000），有效 refresh token 可成功刷新

## 复现日志

以下是从实际触发此问题的日志文件中提取的关键时间线（原日志文件：`~/Library/Application Support/PCL.Mac.Refactor/Logs/Log4.log`）。

### 1. 披风选择触发错误

用户点击更换披风，代码尝试 refresh 令牌，微软返回 `invalid_grant`：

```
[10:43:51] [ERROR] MicrosoftAuthService.swift:145: 调用 API 失败：400 invalid_grant，错误描述：AADSTS70000: The user could not be authenticated as the grant is expired. The user must sign in again.
[10:43:51] [ERROR] CapeSelection.swift:61: 更换披风失败：未能完成操作。（Core.MicrosoftAuthService.Error错误1。）
```

第 1 行 `err()` 日志记录了完整的错误信息（`invalid_grant`、`AADSTS70000`），内容正确。第 2 行 `hint()` 是用户看到的提示，因为 `MicrosoftAuthService.Error` 未实现 `LocalizedError`，`error.localizedDescription` 返回了无意义的类型名字符串。

### 2. 启动游戏触发同一错误

用户尝试启动游戏，同样的 `invalid_grant`：

```
[10:44:36] [ERROR] MinecraftLaunchTask.swift:164: 刷新 accessToken 失败：未能完成操作。（Core.MicrosoftAuthService.Error错误1。）
[10:44:36] [INFO]  MessageBoxManager.swift:152: 正在显示模态框 刷新访问令牌失败
[10:44:43] [INFO]  MessageBoxManager.swift:109: 按钮 取消 被点击
```

旧代码弹出了"刷新访问令牌失败"对话框，并提供了"继续启动"选项。但此时 refresh token 已永久失效，继续启动也无法通过服务器验证。

### 3. 用户重新登录后恢复

```
[10:44:51] [INFO] AccountViewModel.swift:45: 正在请求添加账号
[10:44:54] [INFO] AccountViewModel.swift:110: 获取设备码成功
[10:46:44] [INFO] AccountViewModel.swift:136: 用户完成了授权
[10:46:53] [INFO] AccountViewModel.swift:147: 添加正版账号成功
[10:46:55] [INFO] MessageBoxManager.swift:152: 正在显示模态框 选择披风
```

用户通过完整的登录流程获取新令牌后，披风功能恢复正常。

### 修复后的效果

修复后，同样的场景用户将看到：
- 披风选择："更换披风失败：正版账户登录状态已失效，请重新登录正版账户后再试。"
- 游戏启动："正版账户登录状态已失效"对话框，明确告知需要重新登录，不再提供无效的"继续启动"选项
