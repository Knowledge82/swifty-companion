import '../core/json_reader.dart';

/// Maximum skill level. Confirmed indirectly (the radar scale in the intra),
/// see docs/03, section 11. If it turns out otherwise, only this constant
/// changes.
const double maxSkillLevel = 20;

/// Removes floating-point "noise": 3.4699999999999998 -> 3.47.
double roundLevel(double value) => (value * 100).round() / 100;

/// Skill percentage of the maximum, from 0 to 100.
///
/// This is the only place where the formula is defined. The API has no
/// percentage; the formula `level / max * 100` is ours (see docs/03, section
/// 11).
double skillPercent(double level, {double maxLevel = maxSkillLevel}) {
  if (maxLevel <= 0) {
    return 0;
  }
  return (level / maxLevel * 100).clamp(0, 100).toDouble();
}

class Skill {
  const Skill({this.id, this.name, required this.level});

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: readInt(json['id']),
      name: readString(json['name']),
      level: roundLevel(readDouble(json['level']) ?? 0),
    );
  }

  final int? id;
  /// Name, or `null` if the response has none (the interface substitutes its
  /// own text).
  final String? name;

  /// Level rounded to two decimals.
  final double level;

  double get percent => skillPercent(level);
}
