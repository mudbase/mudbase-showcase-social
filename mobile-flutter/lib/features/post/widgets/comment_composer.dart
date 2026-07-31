import 'package:flutter/material.dart';

const int _commentMaxLength = 300;

/// A pinned text field + send button for adding a comment to a post - capped
/// at 300 chars to match the web app's `CommentComposer`.
class CommentComposer extends StatefulWidget {
  const CommentComposer({required this.onSubmit, super.key});

  final Future<void> Function(String content) onSubmit;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(content);
      _controller.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLength: _commentMaxLength,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
