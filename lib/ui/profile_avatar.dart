import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/photo_loader.dart';

/// A round profile photo.
///
/// It gets several addresses in order of preference and tries them one by one:
/// if the first did not load, the next is taken. If none loaded or there are no
/// addresses, a placeholder with initials (or a little person icon) is shown
/// instead of a crash. While loading, an indicator is visible.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.urls,
    required this.loadPhoto,
    this.initials = '',
    this.size = 224,
  });

  final List<String> urls;

  /// How to download the image bytes by address (in the app this is
  /// `PhotoLoader.load`).
  final PhotoFetcher loadPhoto;

  /// Letters for the placeholder; empty means the little person icon.
  final String initials;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  /// The loading result; `null` if there are no addresses (nothing to load).
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
        // The reason is visible only in debug. Any failure (network, 403, junk)
        // means "try the next address", and in the end "show the placeholder".
        if (kDebugMode) {
          debugPrint('Photo failed to load (${i + 1} of ${urls.length}) (${urls[i]}): $e');
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
            // If the bytes are not an image, we stay with the placeholder.
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
