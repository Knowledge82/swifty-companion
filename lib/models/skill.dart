import '../core/json_reader.dart';

/// Максимальный уровень скилла. Подтверждён косвенно (масштаб радара в интре),
/// см. docs/03, раздел 11. Если окажется иначе, меняется только эта константа.
const double maxSkillLevel = 20;

/// Убирает «шум» чисел с плавающей точкой: 3.4699999999999998 → 3.47.
double roundLevel(double value) => (value * 100).round() / 100;

/// Процент скилла от максимума, от 0 до 100.
///
/// Это единственное место, где задана формула. В API процента нет,
/// формула `level / max × 100` наша (см. docs/03, раздел 11).
double skillPercent(double level, {double maxLevel = maxSkillLevel}) {
  if (maxLevel <= 0) {
    return 0;
  }
  return (level / maxLevel * 100).clamp(0, 100).toDouble();
}

class Skill {
  const Skill({this.id, required this.name, required this.level});

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: readInt(json['id']),
      name: readString(json['name']) ?? 'Без названия',
      level: roundLevel(readDouble(json['level']) ?? 0),
    );
  }

  final int? id;
  final String name;

  /// Уровень, округлённый до двух знаков.
  final double level;

  double get percent => skillPercent(level);
}
