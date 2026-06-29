part of '../entry.dart';

extension _SyncSection on _AppSettingsPageState {
  Widget _buildServerSync() {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.cloud_sync, size: _kIconSize),
      title: const Text('服务器同步'),
      subtitle: Text(
        '多设备数据同步 · 独立账号',
        style: UIs.textGrey,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => ServerSyncPage.route.go(context),
    ).cardx;
  }
}
