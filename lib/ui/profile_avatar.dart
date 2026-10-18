import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/photo_loader.dart';

/// Круглое фото профиля.
///
/// Получает несколько адресов в порядке предпочтения и пробует их по очереди:
/// если первый не загрузился, берётся следующий. Если не загрузился ни один
/// или адресов нет, показывается заглушка с инициалами (или значком человечка),
/// а не падение. Пока идёт загрузка, виден индикатор.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.urls,
    required this.loadPhoto,
    this.initials = '',
    this.size = 224,
  });

  final List<String> urls;

  /// Как скачать байты картинки по адресу (в приложении это `PhotoLoader.load`).
  final PhotoFetcher loadPhoto;

  /// Буквы для заглушки; пусто — значок человечка.
  final String initials;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  /// Результат загрузки; `null`, если адресов нет (грузить нечего).
  Future<Uint8List?>? _photo;

  @override
  void initState() {
    super.initState();
    _photo = _start();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.urls, widget.urls)) {
      _photo = _start();
    }
  }

  Future<Uint8List?>? _start() =>
      widget.urls.isEmpty ? null : _loadFirstAvailable(widget.urls);

  Future<Uint8List?> _loadFirstAvailable(List<String> urls) async {
    for (var i = 0; i < urls.length; i++) {
      try {
        return await widget.loadPhoto(urls[i]);
      } catch (e) {
        // Причина видна только в отладке. Любая неудача (сеть, 403, мусор)
        // означает «пробуем следующий адрес», а в итоге «показываем заглушку».
        if (kDebugMode) {
          debugPrint('Фото не загрузилось (${i + 1} из ${urls.length}) (${urls[i]}): $e');
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: widget.initials.isEmpty
            ? Icon(Icons.person, size: size / 2, color: colors.onSurfaceVariant)
            : Text(
                widget.initials,
                style: TextStyle(
                  fontSize: size / 3,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
      ),
    );

    final photo = _photo;
    final Widget content;
    if (photo == null) {
      content = placeholder;
    } else {
      content = FutureBuilder<Uint8List?>(
        future: photo,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return placeholder;
          }
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            // Если байты не картинка, остаёмся с заглушкой.
            errorBuilder: (_, _, _) => placeholder,
          );
        },
      );
    }

    return ClipOval(
      child: SizedBox(width: size, height: size, child: content),
    );
  }
}
