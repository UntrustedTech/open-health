import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/export/backup.dart';
import 'package:health_app/export/backup_restorer.dart';
import 'package:health_app/theme/app_theme.dart';

/// The choice made when creating a backup.
sealed class BackupProtection {
  const BackupProtection();
}

final class NoPassword extends BackupProtection {
  const NoPassword();
}

final class WithPassword extends BackupProtection {
  const WithPassword(this.password);

  final String password;
}

/// Minimum length of a new backup password. Backups can be copied and
/// attacked offline, so it's longer than a screen-lock PIN.
const minBackupPassword = 10;

/// Asks whether to protect a new backup with a password. Null if cancelled.
/// With [required], "No Password" isn't offered.
Future<BackupProtection?> askBackupProtection(
  BuildContext context, {
  bool required = false,
  String title = 'Protect Backup?',
  String message =
      'A password encrypts the file, so only someone with the password '
      'can read it. If you forget it, the backup can\'t be restored.',
}) => showCupertinoDialog<BackupProtection>(
  context: context,
  builder: (_) =>
      _NewPasswordDialog(required: required, title: title, message: message),
);

/// Asks for the password of an encrypted backup. Null if cancelled.
Future<String?> askBackupPassword(BuildContext context, {String? error}) =>
    showCupertinoDialog<String>(
      context: context,
      builder: (_) => _PasswordDialog(error: error),
    );

/// Shows what a backup holds and asks how to restore it.
Future<RestoreMode?> askRestoreMode(BuildContext context, Backup backup) {
  final when = backup.exportedAt;
  String count(int n, String one, String many) =>
      '${NumberFormat.decimalPattern().format(n)} ${n == 1 ? one : many}';
  return showCupertinoModalPopup<RestoreMode>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: Text(
        when == null
            ? 'Restore Backup?'
            : 'Restore Backup from ${DateFormat.yMMMd().add_jm().format(when.toLocal())}?',
      ),
      message: Text(
        '${count(backup.entries.length, 'health entry', 'health entries')}, '
        '${count(backup.workouts.length, 'workout', 'workouts')} and '
        '${count(backup.routines.length, 'routine', 'routines')}.\n\n'
        '${backup.skipped > 0 ? '${count(backup.skipped, 'record', 'records')} can\'t be read and will be skipped.\n\n' : ''}'
        'Merge adds anything missing and keeps your settings. Replace makes '
        'Health match the backup exactly.',
      ),
      actions: [
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, RestoreMode.merge),
          child: const Text('Merge with Current Data'),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, RestoreMode.replace),
          child: const Text('Replace All Data'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ),
  );
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog({
    this.required = false,
    required this.title,
    required this.message,
  });

  final bool required;
  final String title;
  final String message;

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _protect() {
    final p = _password.text;
    final error = p.length < minBackupPassword
        ? 'Use at least $minBackupPassword characters.'
        : p != _confirm.text
        ? 'The passwords don\'t match.'
        : null;
    if (error != null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, WithPassword(p));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return CupertinoAlertDialog(
      title: Text(widget.required ? 'Backup Password' : widget.title),
      content: Column(
        children: [
          const SizedBox(height: 4),
          Text(widget.message),
          const SizedBox(height: 12),
          _field(_password, 'Password', autofocus: true),
          const SizedBox(height: 8),
          _field(_confirm, 'Confirm Password', onSubmitted: _protect),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error, style: TextStyle(color: context.destructive)),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!widget.required)
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, const NoPassword()),
            child: const Text('No Password'),
          ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _protect,
          child: const Text('Protect'),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({this.error});

  final String? error;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.isEmpty) return;
    Navigator.pop(context, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    return CupertinoAlertDialog(
      title: const Text('Enter Backup Password'),
      content: Column(
        children: [
          const SizedBox(height: 4),
          const Text('This backup is protected with a password.'),
          const SizedBox(height: 12),
          _field(_password, 'Password', autofocus: true, onSubmitted: _submit),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error, style: TextStyle(color: context.destructive)),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}

Widget _field(
  TextEditingController controller,
  String placeholder, {
  bool autofocus = false,
  VoidCallback? onSubmitted,
}) => CupertinoTextField(
  controller: controller,
  placeholder: placeholder,
  obscureText: true,
  autocorrect: false,
  enableSuggestions: false,
  autofocus: autofocus,
  autofillHints: const [AutofillHints.newPassword],
  onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
);
