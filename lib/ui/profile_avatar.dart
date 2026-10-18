import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Круглое фото профиля.
///
/// Получает несколько адресов в порядке предпочтения и пробует их по очереди:
/// если первый не загрузился (например, этой версии нет на CDN), берётся
/// следующий. Если не загрузился ни один или адресов нет, показывается
/// нейтральная заглушка, а не падение.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({super.key, required this.urls, this.size = 112});

  final List<String> urls;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  /// Номер адреса, который пробуем сейчас.
  int _index = 0;

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.urls, widget.urls)) {
      _index = 0;
    }
  }

  /// Переход к следующему адресу откладываем до конца кадра: менять
  /// состояние прямо во время `build` нельзя.
  void _tryNext(int failedIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // `errorBuilder` может сработать не один раз для одного адреса;
      // сравнение номера не даёт перескочить сразу через два.
      if (mounted && _index == failedIndex) {
        setState(() => _index = failedIndex + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final urls = widget.urls;
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.person, size: size / 2),
    );

    final Widget content;
    if (_index >= urls.length) {
      content = placeholder;
    } else {
      final index = _index;
      final url = urls[index];
      content = Image.network(
        url,
        key: ValueKey(url),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Причина видна только в отладке. Адрес картинки публичный
          // (CDN интры), секретов в нём нет.
          if (kDebugMode) {
            debugPrint(
              'Фото не загрузилось (${index + 1} из ${urls.length}) '
              '($url): $error',
            );
          }
          _tryNext(index);
          return placeholder;
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
      );
    }

    return ClipOval(
      child: SizedBox(width: size, height: size, child: content),
    );
  }
}
