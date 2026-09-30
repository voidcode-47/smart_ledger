# 手机端 UI 重设计：数字优先（Linear / Things 3 风格）

## Context（为什么重做）

前一版方案被拒，原因是"AI 味"——shimmer + 双色渐变 + 金色描边 + 微交互堆砌是 frontend-design 技能明确列举的 SaaS-card kit 套路，散乱而无主张。

新方案核心：**一个 signature moment，其他全部安静**。参考 Linear / Stripe / Things 3，让排版和数字本身成为视觉英雄，移除所有装饰性模糊和渐变。性能自然提升（无 BackdropFilter = 稳 60fps）。

## 设计原则

1. **数字优先**：金额是记账 App 的主角，用字号 + 字重建立层次，不用阴影/渐变/模糊。
2. **一个 signature moment**：仪表盘的"本月结余"大数字是视觉锚点，其他元素保持克制。
3. **结构即信息**：边框、分隔线、对齐都是信息编码，不是装饰。
4. **克制色彩**：teal #0F766E 仅用于关键交互和语义色，其他全部中性色（黑/白/灰）。
5. **移除装饰**：不加 shimmer、不加双色渐变、不加金色高光、不加 staggered 入场、不加散乱微交互——这些都是 AI 味套路。

## 设计 Token（lib/utils/app_theme.dart）

```
背景：浅色 #FAFAFA / 深色 #0A0A0A（纯色，无渐变）
表面：浅色 #FFFFFF / 深色 #141414
分隔线：浅色 #E5E5E5 / 深色 #262626
文字主：浅色 #0A0A0A / 深色 #FAFAFA
文字次：浅色 #737373 / 深色 #A3A3A3
文字弱：浅色 #A3A3A3 / 深色 #737373
主色 teal：#0F766E（仅按钮/选中/Hero）
收入：#16A34A
支出：#DC2626
```

**移除**：accentDeep / accentGold / heroGradientDeep / shimmerColor（前一版 AI 味 token）
**移除**：glassFill / glassFillStrong / glassBorder / glassBlurSigma / glassShadow / accentGradient（玻璃拟态 token）

## 排版系统（用字重 + 字号建立层次）

```
Display（Hero 大数字）   : 56sp / w800 / tabular nums / letter-spacing -1.0
H1（页面标题）           : 28sp / w700 / letter-spacing -0.5
H2（区块标题）           : 18sp / w700
Body                     : 15sp / w400
Caption（标签）          : 11sp / w500 / 灰色
Numeric（金额）          : 16sp / w600 / tabular nums
```

不引入新字体（避免 bundle 体积），用系统 SF/Roboto + 精心调校字距和字重。

## 实施步骤

### 步骤 1：背景与全局色板重做

**`lib/widgets/gradient_background.dart`**
- 移除 3 个 `ImageFilter.blur(sigma=55)` 光斑（性能瓶颈 + 装饰）。
- 背景改纯色（`AppTheme.surface`）：浅色 #FAFAFA，深色 #0A0A0A。
- 自定义背景图功能保留（用户图片背景不受影响）。
- 整个 widget 简化为 `ColoredBox` + child。

**`lib/utils/app_theme.dart`**
- 按上面 token 表替换，移除所有 glass* 和 accentGradient getter。
- 保留 `setDark` / `isDark` / 语义色 / `onSurface` 兼容方法。
- `theme()` / `darkTheme()` 更新 `scaffoldBackgroundColor` 为新表面色。

### 步骤 2：仪表盘 signature moment（lib/views/dashboard/dashboard_screen.dart）

**`_balanceHero` 重写为"大数字 Hero"：**
- 移除双色渐变背景、移除装饰圆圈、移除 boxShadow。
- 背景纯色（浅色 #FFFFFF 卡片 / 深色 #141414 卡片），1px 分隔线。
- 布局：
  ```
  ┌──────────────────────────┐
  │ 本月结余                  │  ← 11sp 灰色标签
  │                          │
  │ ¥ 12,345.67              │  ← 56sp w800 tabular nums 主色 teal
  │                          │
  │ 收入 ¥18,000  支出 ¥5,654 │  ← 13sp 灰色，tabular nums
  └──────────────────────────┘
  ```
- 数字滚动保留 `CountUpText`，曲线改 `Curves.easeOutCubic`。
- 不加 shimmer、不加渐变、不加光斑——数字本身就是焦点。

**`_monthHeader` 重写：**
- 移除 `BackdropFilter` 玻璃胶囊。
- 改纯色卡片 + 1px 描边，极简文字 + 左右箭头。

**"最近流水" 卡片：**
- 不用 `GlassCard`，改纯色 Container + 1px 描边。

**`QuoteCard`、`BudgetCard`、`CategoryDonutCard`：**
- 同步去掉 `GlassCard` 包装，改纯色卡片。

### 步骤 3：底部导航重做（lib/views/home_screen.dart）

**`_buildGlassBottomBar` 改名为 `_buildBottomBar`：**
- 移除 `BackdropFilter`、移除 glassShadow、移除渐变填充。
- 改纯色背景（浅色 #FFFFFF / 深色 #141414），顶部 1px 分隔线。
- 选中态：图标变填充 teal，标签 teal w600。
- 未选中：图标 outline 灰 #A3A3A3，标签灰 w400。
- **移除** AnimatedContainer 选中胶囊（AI 味装饰）。
- 切换瞬间完成，无滑入动画。

**`_gradientAddButton` 改为 `_AddButton`：**
- 移除渐变（accentGradient）、移除发光阴影（accentGlow）。
- 改纯 teal #0F766E 圆形按钮，白色 + 图标。
- 按下微缩 0.98（仅此一处微交互）。

**`_textAddFab`：**
- 移除 glassFillStrong 背景。
- 改纯色卡片 + 1px 描边。

### 步骤 4：加账表单重做（lib/views/add_transaction/add_transaction_sheet.dart）

**金额显示区：**
- 移除 glassFill 渐变填充。
- 改纯色背景 + 超大数字 48sp w800 tabular nums。
- 光标闪烁、键盘数字输入有节奏感。

**类型切换（支出/收入）：**
- 移除渐变填充和辉光阴影。
- 改 Linear 风格 segmented control：纯色背景 + 选中态 teal 文字 + 1px 底部下划线。

**分类网格 `_categoryItem`：**
- 移除选中态渐变 + 辉光阴影。
- 改：圆形图标描边 1.5px，选中态 teal 描边 + 浅 teal 底，未选中灰描边。
- 标签下方 11sp 灰色。

**保存按钮：**
- 移除渐变。
- 改纯 teal #0F766E 矩形按钮，白色文字 w600。

### 步骤 5：流水列表重做（lib/views/ledger/ledger_screen.dart + lib/widgets/transaction_tile.dart）

**流水条目改极简卡片（Things 3 风格）：**
- 圆角 12，纯色背景，无阴影。
- 左侧：分类图标圆形描边 1.5px（非填充），36x36。
- 中间：分类名 15sp w500 主色 + 备注 13sp 灰色。
- 右侧：金额 16sp w600 tabular nums 右对齐，支出红 / 收入绿。
- 日期分组用 11sp 灰色 w500 小标题，无背景胶囊。
- 移除 `GlassCard` 包装。

### 步骤 6：统计页重做（lib/views/statistics/statistics_screen.dart + lib/widgets/donut_chart.dart）

**圆环图：**
- 不用彩虹色分类。改用 teal 不同透明度（0.4 / 0.55 / 0.7 / 0.85 / 1.0）按金额排序。
- 描边 1.5px，无填充阴影。
- 中心显示总支出大数字。

**折线图：**
- 细线 1.5px teal，无填充阴影。
- 坐标轴极简 11sp 灰色。

**移除所有 `GlassCard` 包装**，改纯色卡片 + 1px 描边。

### 步骤 7：GlassCard 退役

**`lib/widgets/glass_card.dart`：**
- 保留文件但内部改实现：纯色 Container + 1px 描边 + 圆角，无 BackdropFilter。
- API 不变（child/padding/borderRadius/color），向后兼容既有调用。
- `color` 参数仍可用（指定纯色填充）。
- 这样新旧代码都能用，无需大规模重构。

### 步骤 8：StaggeredItem 简化

**`lib/widgets/staggered_item.dart`：**
- 入场动画改简单 fade-in（200ms），不用 staggered 交错（AI 味）。
- 或者直接移除动画，列表瞬间显示（更克制）。

## 关键文件清单

| 文件 | 改动核心 |
|------|----------|
| `lib/utils/app_theme.dart` | token 重写：移除 glass*，纯色背景 |
| `lib/widgets/gradient_background.dart` | 移除光斑模糊，纯色背景 |
| `lib/widgets/glass_card.dart` | 内部改纯色卡片 + 描边，API 不变 |
| `lib/views/dashboard/dashboard_screen.dart` | Hero 大数字重写，移除装饰 |
| `lib/views/home_screen.dart` | 底部导航极简，FAB 纯色 |
| `lib/views/add_transaction/add_transaction_sheet.dart` | 金额大数字，分类描边选中 |
| `lib/views/ledger/ledger_screen.dart` | 流水卡片极简 |
| `lib/widgets/transaction_tile.dart` | Things 3 风格条目 |
| `lib/views/statistics/statistics_screen.dart` | 圆环单色透明度，移除玻璃 |
| `lib/widgets/donut_chart.dart` | teal 透明度梯度 |
| `lib/widgets/staggered_item.dart` | 简化或移除入场动画 |
| `lib/widgets/quote_card.dart` / `lib/widgets/budget_card.dart` | 移除 GlassCard 包装 |

## 不做的事（避免 AI 味 + 避免过度工程）

- ❌ 不加 shimmer 扫光（AI 味）
- ❌ 不加双色渐变（AI 味）
- ❌ 不加金色高光（AI 味）
- ❌ 不加 staggered 交错入场（AI 味）
- ❌ 不加散乱微交互（每处都加动画 = 没重点）
- ❌ 不加全屏粒子/动态背景（散乱装饰）
- ❌ 不引入新字体包（bundle 体积）
- ❌ 不动 Windows 桌面端布局
- ❌ 不改 SQLite/Riverpod 业务层
- ❌ 不重写组件 API，只换内部实现

## 验证方法

1. **视觉验证（重点）**：
   ```powershell
   flutter run -d windows
   ```
   - 仪表盘 Hero 大数字是否成为视觉锚点
   - 整体是否"安静但有主张"
   - 流水列表层次是否靠排版而非阴影
   - 底部导航是否极简不花哨

2. **性能验证（自然提升）**：
   ```powershell
   flutter run --profile
   ```
   - 切换 tab、滚动列表、打开加账表单应稳 60fps（无 BackdropFilter）

3. **回归测试**：
   ```powershell
   flutter analyze
   flutter test
   ```
   - 83 项测试应全部通过（GlassCard API 兼容）

4. **真机验证**：
   ```powershell
   flutter build apk --release --split-per-abi
   ```
   - 安装到手机感受流畅度和视觉冲击

## 与前一版的关键差异

| 维度 | 前版（AI 味） | 新版（有主张） |
|------|--------------|----------------|
| 视觉焦点 | 到处加效果，无重点 | 一个 Hero 大数字 |
| 色彩 | teal + 深蓝紫 + 金色高光 | teal + 中性色（克制） |
| 装饰 | 双色渐变 + shimmer + 光斑 | 无装饰，排版驱动 |
| 动画 | staggered 入场 + 光标滑入 + 微交互堆砌 | 仅数字滚动 + 按下微缩 |
| 玻璃拟态 | 减少到 3 处 | 全部移除（性能自然提升） |
| 底部导航 | 玻璃胶囊 + 光标动画 | 纯色 + 选中态文字色 |
| 流水条目 | 玻璃卡 + 阴影 | 纯色 + 描边 + 排版层次 |
