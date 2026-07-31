import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mudbase_exception.dart';
import '../../../data/repository_providers.dart';
import '../../auth/auth_controller.dart';
import '../feed_controller.dart';

const int _contentMaxLength = 500;

/// A modal bottom sheet for composing a new post - text (required, capped at
/// 500 chars to match the web app) + an optional pasted image URL (see
/// `plan/build-plan.md` "Known limitations" for why this is a text field and
/// not a picker: no project end-user JWT, including a real verified
/// `customer`, can ever pass Mudbase's file-upload permission check).
///
/// On success, prepends the new post into [FeedController]'s cache
/// immediately (an optimistic-equivalent insert using the real server
/// response) - `FeedController.prependPost` dedupes by `id`, so if this same
/// post also arrives moments later via the realtime `db:create` echo, it is
/// a no-op.
Future<void> showPostComposerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _PostComposerSheet(),
  );
}

class _PostComposerSheet extends ConsumerStatefulWidget {
  const _PostComposerSheet();

  @override
  ConsumerState<_PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends ConsumerState<_PostComposerSheet> {
  final _contentController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _contentController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _errorMessage = 'Say something before posting.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final user = ref.read(authControllerProvider).valueOrNull;
      if (user == null) throw StateError('Must be signed in to post');
      final authNotifier = ref.read(authControllerProvider.notifier);
      final repository = ref.read(postRepositoryProvider);
      final imageUrl = _imageUrlController.text.trim();
      final created = await authNotifier.callAuthorized(
        (token) => repository.create(
          token: token,
          authorId: user.id,
          authorName: user.fullName,
          content: content,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
        ),
      );
      ref.read(feedControllerProvider.notifier).prependPost(created);
      if (mounted) Navigator.of(context).pop();
    } on MudbaseException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'New post',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _contentController,
            maxLength: _contentMaxLength,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: "What's on your mind?",
              alignLabelWithHint: true,
            ),
          ),
          TextField(
            controller: _imageUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Image URL (optional)',
              hintText: 'https://...',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
    );
  }
}
