import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api_exception.dart';
import '../core/login.dart';
import '../data/photo_loader.dart';
import '../data/user_repository.dart';
import '../l10n/app_strings.dart';
import 'error_banner.dart';
import 'profile_screen.dart';
import 'steampunk/gears.dart';
import 'steampunk/steampunk_theme.dart';
import 'steampunk/steampunk_widgets.dart';

/// Screen 1: the login field, the search button, a loading indicator, an error
/// message.
///
/// Screen states:
/// - waiting: the field and the button are active;
/// - loading (`_loading`): the button shows an indicator and cannot be pressed;
/// - input error (`_fieldError`): red text under the field, no request was
///   sent;
/// - request error (`_requestError`): a banner under the button;
/// - success: the profile screen opens.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.repository,
    required this.photoLoader,
  });

  final UserRepository repository;
  final PhotoLoader photoLoader;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = false;
  LoginProblem? _fieldError;
  ApiException? _requestError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Protection against a double tap while the previous request has not
    // finished.
    if (_loading) {
      return;
    }

    final raw = _controller.text;
    final validation = validateLogin(raw);
    if (validation != null) {
      setState(() {
        _fieldError = validation;
        _requestError = null;
      });
      return;
    }

    setState(() {
      _fieldError = null;
      _requestError = null;
      _loading = true;
    });

    try {
      final profile = await widget.repository.fetchUser(raw);
      // While the request was running, the screen could have been closed: after
      // an await you may touch the context only after making sure the widget is
      // still in the tree.
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            profile: profile,
            loadPhoto: widget.photoLoader.load,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _requestError = e;
        _loading = false;
      });
    } catch (e, stackTrace) {
      // Only an error in our own code gets here. We show the user a general
      // message, and in debug we print the details.
      if (kDebugMode) {
        debugPrint('Unexpected error: $e\n$stackTrace');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _requestError = const UnexpectedResponseException();
        _loading = false;
      });
    }
  }

  void _clearErrors() {
    if (_fieldError != null || _requestError != null) {
      setState(() {
        _fieldError = null;
        _requestError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final requestError = _requestError;
    final fieldError = _fieldError;
    return Scaffold(
      appBar: AppBar(title: Text(strings.appTitle), bottom: const BrassLine()),
      body: SteampunkBackdrop(
        child: SafeArea(
          child: Center(
            // Scrolling saves from overflow when the keyboard is open or the
            // screen is rotated.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: GearEmblem(size: 160)),
                    const SizedBox(height: 20),
                    BrassPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _controller,
                            enabled: !_loading,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => _clearErrors(),
                            onSubmitted: (_) => _submit(),
                            decoration: steampunkInputDecoration(
                              label: strings.loginLabel,
                              errorText: fieldError == null
                                  ? null
                                  : strings.loginProblemText(fieldError),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(strings.searchButton),
                          ),
                          if (requestError != null) ...[
                            const SizedBox(height: 16),
                            ErrorBanner(error: requestError),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
