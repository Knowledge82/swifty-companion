import 'package:flutter/material.dart';

/// Круглое фото профиля. Без адреса, при ошибке загрузки и пока картинка
/// грузится показывается нейтральная заглушка/индикатор, но не падение.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.url, this.size = 112});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.person, size: size / 2),
    );
    final imageUrl = url;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? placeholder
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),
      ),
    );
  }
}
