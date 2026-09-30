# smart_ledger（智慧记账）

跨端个人财务管理助手，支持 **Windows 桌面端** 与 **Android 手机端**。

![platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows-teal) ![flutter](https://img.shields.io/badge/Flutter-3.x-02569B) ![version](https://img.shields.io/badge/version-1.0.0-2BB7A8) ![license](https://img.shields.io/badge/license-MIT-0F766E)

## 功能

- **记账**：支出/收入录入（数字键盘）、快速记账（系统托盘）、备注、日期选择
- **图片识别记账**（Android）：拍照/相册选图，本地 OCR 自动识别金额、分类、日期并填入表单，确认后保存
- **流水总览**：全部流水按月分组，支持关键词搜索（备注/分类）、类型筛选（全部/支出/收入）、分类筛选；删除入口四选一：左滑 / 长按 / 删除图标 / 编辑页内删除
- **预算管理**：按月设置预算，仪表盘实时显示已支出/剩余/超支进度条
- **分类管理**：内置分类可改名换图标换色，支持新增/删除自定义分类（删除后流水自动归入"其他"）
- **统计报表**：近 7/30 天支出趋势折线图、分类占比圆环图、本月分类支出排行（金额/占比/环比）、分类筛选
- **仪表盘**：名言卡（内置 75+ 条，联网自动刷新、点击复制、可换一条；弱网 3 秒内回退本地）、月度收入/支出/结余汇总、预算进度、分类占比、最近流水
- **外观设置**：白色 / 黑色两套背景主题随时切换并记住选择（黑色主题自动进入**完整深色模式**：卡片、文字、输入框、弹窗整体适配）；支持自定义图片背景（多张/透明度/框选，选择主题后自动停用）
- **趣味工具**：随机转盘（吃什么/喝什么/去哪儿玩，选项可自定义）；小游戏合集（Android）——内置 115 款**零依赖单文件** HTML5 开源小游戏（MIT 许可，离线可玩、无外部 CDN），支持搜索、分类筛选与 SSS-D 质量分级，键盘类游戏内置虚拟按键，手机可玩
- **数据管理**：SQLite 自动迁移（当前 v3）、数据库备份/恢复（zip）、CSV 导出/导入（兼容旧版枚举分类名）
- **安全**：Android 生物识别锁（指纹/面容）
- **桌面体验**：关闭窗口最小化到系统托盘、托盘快速记账

## 技术栈

- Flutter 3.x + Riverpod（状态管理）
- SQLite（sqflite / sqflite_common_ffi，跨端统一）
- fl_chart（图表）、window_manager + tray_manager（桌面端）

## 构建与启动

详见 [启动指南.md](./启动指南.md)。快速开始：

```powershell
flutter pub get
flutter run -d windows        # Windows 调试
flutter build apk --release   # Android 正式包（全 ABI 大包）
flutter build apk --release --split-per-abi   # 按 ABI 拆分（推荐，体积小）
```

## 测试

```powershell
flutter analyze     # 静态分析
flutter test        # 全部单元测试 / 组件回归测试
```

测试覆盖：金额与 OCR 文本解析、分类工具、记账表单分类默认选中一致性、深浅色板切换、主题刷新、转盘流程、游戏目录与页面渲染等。

## 开源许可

本项目基于 [MIT License](./LICENSE) 开源。

内置的 115 款 HTML5 小游戏来自开源项目 [wangzifan396-wzf/mini-browser-games](https://github.com/wangzifan396-wzf/mini-browser-games)（MIT），版权归各自作者所有；名言数据来自公开的[一言接口](https://hitokoto.cn)，仅在主动刷新时联网请求。

## 说明

- 数据存储于本机 SQLite，无网络依赖；备份/恢复与 CSV 导入导出用于换机迁移。
- 图片识别仅 Android 可用（本地 ML Kit，离线免费）；Windows 版不显示该入口。识别为"建议填入"，保存前请核对金额与分类。
- 小游戏合集仅 Android 可用（WebView 组件）；115 款游戏均为 MIT 许可的开源单文件项目，源码位于 `assets/minigames/`，来源与许可信息见「小游戏合集」列表与上游仓库。
- 数据库 Schema 版本 v3：`categories` 表管理自定义分类，`budgets` 表按月存储预算，`transactions.category` 存分类名称。
- Windows 版关闭窗口后会驻留系统托盘，重新构建前请先彻底退出应用（托盘图标右键退出）。
- Android release 未开启 R8 混淆（google_mlkit 按需引用多语言 OCR 类，混淆会报 Missing class；自用应用无需混淆）。
