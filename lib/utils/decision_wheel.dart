import 'package:flutter/material.dart';

/// 转盘预设选项集
class WheelPreset {
  const WheelPreset(this.name, this.options);

  final String name;
  final List<String> options;
}

/// 随机转盘核心逻辑（纯 Dart，便于单元测试）
class DecisionWheel {
  DecisionWheel._();

  static const String prefKey = 'decision_wheel_options';

  /// 内置预设
  static const List<WheelPreset> presets = [
    WheelPreset('今天吃什么', [
      '米饭套餐',
      '面条',
      '饺子',
      '火锅',
      '烧烤',
      '麻辣烫',
      '汉堡薯条',
      '沙拉轻食',
      '披萨',
      '粥',
      '寿司',
      '炒饭',
    ]),
    WheelPreset('今天喝什么', [
      '白开水',
      '奶茶',
      '咖啡',
      '果汁',
      '柠檬水',
      '豆浆',
      '酸奶',
      '可乐',
    ]),
    WheelPreset('去哪儿玩', [
      '公园',
      '商场',
      '电影院',
      '图书馆',
      '咖啡馆',
      '健身房',
      '周边游',
      '宅家',
    ]),
    WheelPreset('周末安排', [
      '大扫除',
      '看书',
      '追剧',
      '运动',
      '逛街',
      '做饭',
      '早睡',
      '发呆',
    ]),
  ];

  /// 指针固定在顶部，转盘顺时针累计旋转 [spinDeg] 度后，
  /// 命中的扇区下标（扇区从顶部开始顺时针编号）。
  static int sectorAtAngle(double spinDeg, int count) {
    if (count <= 0) return -1;
    final sweep = 360.0 / count;
    final normalized = ((spinDeg % 360) + 360) % 360;
    return (normalized / sweep).floor().clamp(0, count - 1);
  }

  /// 生成一圈稳定可读的扇区颜色（深色系，保证白色文字对比度）
  static List<Color> sectorColors(int count) {
    const palette = [
      Color(0xFF0F766E),
      Color(0xFFDC2626),
      Color(0xFFD97706),
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFF059669),
      Color(0xFFEA580C),
      Color(0xFF4F46E5),
      Color(0xFF0E7490),
      Color(0xFFB45309),
      Color(0xFFBE185D),
    ];
    return [
      for (var i = 0; i < count; i++) palette[i % palette.length],
    ];
  }

  /// 把用户输入拆分为选项：按空白 / 逗号 / 顿号 / 分号分隔，去空去重
  static List<String> parseOptions(String raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final part in raw.split(RegExp(r'[\s,，、;；]+'))) {
      final s = part.trim();
      if (s.isEmpty || seen.contains(s)) continue;
      seen.add(s);
      result.add(s);
    }
    return result;
  }
}
