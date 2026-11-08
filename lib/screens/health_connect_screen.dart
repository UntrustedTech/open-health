import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/platform/device_profile.dart';
import 'package:health_app/screens/privacy_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/health_source.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Connect, monitor and disconnect Health Connect (Apple Health on iOS).
class HealthConnectScreen extends StatelessWidget {
  const HealthConnectScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: context.read<HealthSyncService>().sourceName,
      builder: (_) => const HealthConnectScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<HealthSyncService>();
    final device = context.watch<DeviceProfile>();
    return LargeTitlePage(
      title: sync.sourceName,
      children: [
        _Hero(sourceName: sync.sourceName),
        ...switch (sync.status) {
          null => [const Center(child: CupertinoActivityIndicator())],
          SourceStatus.unsupported => [_Unsupported(device: device)],
          SourceStatus.needsInstall => [const _Install()],
          SourceStatus.available when !sync.connected => [const _Connect()],
          SourceStatus.available => [const _Connected()],
        },
        if (device.isSamsung && sync.status != SourceStatus.unsupported)
          const GroupedSection(
            header: 'Samsung Health',
            footer:
                'In Samsung Health, open Settings › Health Connect and '
                'allow it to share data, so your Galaxy Watch and '
                'Samsung Health data appear here.',
            hasLeading: false,
            children: [
              CupertinoListTile(
                title: Text('Galaxy phone detected'),
                leading: Icon(Icons.smartphone_rounded),
              ),
            ],
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.sourceName});

  final String sourceName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const IconTile(
          icon: Icons.favorite_rounded,
          color: AppTheme.accent,
          size: 64,
        ),
        const SizedBox(height: 12),
        Text(sourceName, style: context.title2, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'Health reads steps, workouts, sleep, heart rate and more that your '
          'phone, watch and other apps save to $sourceName. Health only reads '
          'this data and never changes it.',
          textAlign: TextAlign.center,
          style: context.subheadline.copyWith(color: context.secondaryLabel),
        ),
        CupertinoButton(
          onPressed: () => PrivacyScreen.open(context),
          child: const Text('How Your Data Is Used'),
        ),
      ],
    );
  }
}

class _Unsupported extends StatelessWidget {
  const _Unsupported({required this.device});

  final DeviceProfile device;

  @override
  Widget build(BuildContext context) {
    return GroupedSection(
      hasLeading: false,
      footer: device.isAndroid
          ? 'Health Connect needs Android 8.0 or newer. This phone runs '
                '${device.systemName}.'
          : null,
      children: const [
        CupertinoListTile(title: Text('Not available on this device')),
      ],
    );
  }
}

class _Install extends StatelessWidget {
  const _Install();

  @override
  Widget build(BuildContext context) {
    final sync = context.read<HealthSyncService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoButton.filled(
          onPressed: sync.openInstallPage,
          child: const Text('Install Health Connect'),
        ),
        const SizedBox(height: 8),
        Text(
          'Health Connect is a free app from Google. After installing or '
          'updating it, return here to connect.',
          textAlign: TextAlign.center,
          style: context.footnote.copyWith(color: context.secondaryLabel),
        ),
      ],
    );
  }
}

class _Connect extends StatefulWidget {
  const _Connect();

  @override
  State<_Connect> createState() => _ConnectState();
}

class _ConnectState extends State<_Connect> {
  bool _busy = false;

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      await context.read<HealthSyncService>().connect();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<HealthSyncService>();
    final error = sync.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoButton.filled(
          onPressed: _busy ? null : _connect,
          child: _busy
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : Text('Connect ${sync.sourceName}'),
        ),
        const SizedBox(height: 8),
        Text(
          error ??
              'You choose which data to share on the next screen. Allow '
                  '"Access past data" to import more than the last 30 days.',
          textAlign: TextAlign.center,
          style: context.footnote.copyWith(
            color: error == null ? context.secondaryLabel : context.destructive,
          ),
        ),
      ],
    );
  }
}

class _Connected extends StatelessWidget {
  const _Connected();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<HealthSyncService>();
    final store = context.watch<HealthStore>();
    final last = sync.lastSync;
    final progress = sync.progress;
    final error = sync.error;
    final name = sync.sourceName;
    final appleHealth = defaultTargetPlatform == TargetPlatform.iOS;
    final types = MetricType.values
        .where(sync.supportedTypes.contains)
        .toList();
    final allowed = types.where(sync.granted.contains).length;
    final recent = sync.recentAccess;

    return Column(
      children: [
        GroupedSection(
          header: 'Sync',
          footer: error,
          hasLeading: false,
          children: [
            InfoRow(
              title: 'Last Synced',
              value: (sync.syncing
                  ? 'Syncing… ${((progress ?? 0) * 100).round()}%'
                  : last == null
                  ? 'Never'
                  : _when(last, store.today)),
            ),
            InfoRow(
              title: 'Imported History',
              value: sync.historyAllowed ? 'Past year' : 'Past 30 days',
            ),
            InfoRow(
              title: 'Sync Now',
              titleColor: sync.syncing ? context.tertiaryLabel : context.tint,
              trailing: sync.syncing
                  ? const CupertinoActivityIndicator()
                  : null,
              onTap: sync.syncing ? null : () => sync.sync(force: true),
            ),
          ],
        ),
        GroupedSection(
          header: 'Automatic Sync',
          footer:
              sync.settingsError ??
              (sync.backgroundSync
                      ? 'Health checks $name about every '
                            '${_interval(sync.backgroundInterval)} while it\'s '
                            'closed. Android may check less often to save battery.'
                      : 'With Background Sync off, Health only syncs while it\'s '
                            'open.') +
                  (sync.syncOnOpen
                      ? ' Checking more often while open shows watch data '
                            'sooner but uses a little more battery.'
                      : ''),
          hasLeading: false,
          children: [
            InfoRow(
              title: 'Sync When App Opens',
              subtitle: 'Fetch new data on opening',
              trailing: CupertinoSwitch(
                value: sync.syncOnOpen,
                onChanged: sync.setSyncOnOpen,
              ),
            ),
            if (sync.syncOnOpen)
              InfoRow(
                title: 'While Open, Check Every',
                value: _interval(sync.openInterval),
                chevron: true,
                onTap: () => _pickInterval(
                  context,
                  title: 'While Open, Check for New Data Every',
                  options: HealthSyncService.openIntervals,
                  current: sync.openInterval,
                  onPicked: sync.setOpenInterval,
                ),
              ),
            // Not on iPhone: see the scheduler in main.dart.
            if (!appleHealth)
              InfoRow(
                title: 'Background Sync',
                subtitle: 'Check while Health is closed',
                trailing: CupertinoSwitch(
                  value: sync.backgroundSync,
                  onChanged: sync.setBackgroundSync,
                ),
              ),
            if (sync.backgroundSync && !appleHealth)
              InfoRow(
                title: 'Check Every',
                value: _interval(sync.backgroundInterval),
                chevron: true,
                onTap: () => _pickInterval(
                  context,
                  title: 'Check for New Data Every',
                  options: HealthSyncService.intervals,
                  current: sync.backgroundInterval,
                  onPicked: sync.setBackgroundInterval,
                ),
              ),
          ],
        ),
        GroupedSection(
          header: 'Permissions',
          // Apple Health never tells apps what they may read, and there's
          // no link to this app's page in it: the steps are spelled out.
          footer: appleHealth
              ? 'In the Health app, tap your profile picture, then Apps › '
                    'Health, to choose what Health can read.'
              : 'Choose what Health can read in $name. Changes show up when '
                    'you come back here.',
          children: [
            InfoRow(
              leading: IconTile(
                icon: Icons.lock_open_rounded,
                color: context.tint,
              ),
              title: 'Manage Permissions',
              value: appleHealth ? null : '$allowed of ${types.length}',
              chevron: true,
              onTap: sync.openPermissionSettings,
            ),
            if (!appleHealth)
              for (final t in types)
                InfoRow(
                  leading: IconTile(icon: t.icon, color: t.color),
                  title: t.label,
                  value: sync.granted.contains(t) ? null : 'Not Allowed',
                  trailing: sync.granted.contains(t)
                      ? Icon(
                          Icons.check_rounded,
                          color: context.tint,
                          semanticLabel: tr('Allowed'),
                        )
                      : null,
                ),
          ],
        ),
        if (!appleHealth)
          GroupedSection(
            header: name,
            footer:
                'Opens $name\'s Data and access: your data by type, and '
                'the apps that can use it.',
            children: [
              InfoRow(
                leading: IconTile(
                  icon: Icons.storage_rounded,
                  color: Palette.blue,
                ),
                title: 'Data & Access',
                chevron: true,
                onTap: sync.openDataSettings,
              ),
            ],
          ),
        GroupedSection(
          header: 'Recent Access',
          footer: recent.isEmpty
              ? 'Each time Health reads $name, it shows here.'
              : recent.length == 1
              ? 'The one time Health has read $name so far.'
              : 'The last ${recent.length} times Health read $name.',
          children: [
            if (recent.isEmpty)
              const InfoRow(title: 'No access yet')
            else
              for (final r in recent.take(_recentShown))
                _AccessRow(record: r, today: store.today),
            if (recent.length > _recentShown)
              InfoRow(
                title: 'Show All',
                titleColor: context.tint,
                chevron: true,
                onTap: () => RecentAccessScreen.open(context),
              ),
          ],
        ),
        GroupedSection(
          hasLeading: false,
          children: [
            InfoRow(
              title: 'Disconnect',
              titleColor: context.destructive,
              onTap: () => _confirmDisconnect(context),
            ),
          ],
        ),
      ],
    );
  }

  /// Recent syncs listed on this page; the rest are a tap away.
  static const _recentShown = 5;

  Future<void> _pickInterval(
    BuildContext context, {
    required String title,
    required List<Duration> options,
    required Duration current,
    required Future<void> Function(Duration) onPicked,
  }) async {
    final picked = await showCupertinoModalPopup<Duration>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final d in options)
            CupertinoActionSheetAction(
              isDefaultAction: d == current,
              onPressed: () => Navigator.pop(context, d),
              child: Text(_interval(d)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked != null) await onPicked(picked);
  }

  Future<void> _confirmDisconnect(BuildContext context) async {
    final sync = context.read<HealthSyncService>();
    final ok = await confirmDestructive(
      context,
      title: 'Disconnect ${sync.sourceName}?',
      message:
          'Data imported from ${sync.sourceName} will be removed from this '
          'app. Data you entered here is kept, and nothing is deleted from '
          '${sync.sourceName}.',
      action: 'Disconnect',
    );
    if (ok) await sync.disconnect();
  }
}

/// "15 min", "1 hr", "6 hrs".
String _interval(Duration d) => d.inMinutes < 60
    ? '${d.inMinutes} min'
    : '${d.inHours} ${d.inHours == 1 ? 'hr' : 'hrs'}';

String _when(DateTime at, DateTime today) =>
    '${formatDay(at, today)}, ${formatTime(at)}';

/// One read of the health platform: what started it, when, and what came
/// of it.
class _AccessRow extends StatelessWidget {
  const _AccessRow({required this.record, required this.today});

  final SyncRecord record;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return InfoRow(
      leading: IconTile(
        icon: r.ok ? _icon(r.trigger) : Icons.error_outline_rounded,
        color: r.ok ? Palette.green : Palette.red,
      ),
      title: r.trigger.label,
      subtitle: r.ok
          ? (r.readings == 0
                ? 'Nothing new'
                : '${r.readings} new ${r.readings == 1 ? 'reading' : 'readings'}')
          : r.error ?? 'Failed',
      value: _when(r.at, today),
    );
  }

  static IconData _icon(SyncTrigger t) => switch (t) {
    SyncTrigger.connect => Icons.link_rounded,
    SyncTrigger.launch || SyncTrigger.resume => Icons.open_in_new_rounded,
    SyncTrigger.manual => Icons.sync_rounded,
    SyncTrigger.periodic => Icons.autorenew_rounded,
    SyncTrigger.background => Icons.schedule_rounded,
  };
}

/// Every recent read of the health platform.
class RecentAccessScreen extends StatelessWidget {
  const RecentAccessScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Recent Access',
      builder: (_) => const RecentAccessScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<HealthSyncService>();
    final today = context.select<HealthStore, DateTime>((s) => s.today);
    return LargeTitlePage(
      title: 'Recent Access',
      children: [
        GroupedSection(
          footer:
              'For other apps\' access, open ${sync.sourceName} › Data & '
              'Access.',
          children: [
            for (final r in sync.recentAccess)
              _AccessRow(record: r, today: today),
          ],
        ),
      ],
    );
  }
}
