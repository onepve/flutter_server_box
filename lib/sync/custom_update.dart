import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/res/url.dart';

/// 自定义更新对话框，显示下载地址 + 一键直达 + 跳过此版本
Future<void> showCustomUpdateDialog({
  required BuildContext context,
  required String githubReleasesUrl,
  required int build,
  String? storeUrl,
}) async {
  if (isWeb) return;

  // 1. 获取更新信息
  try {
    await AppUpdate.fromGitHubReleasesUrl(
      url: githubReleasesUrl,
      build: build,
      storeUrl: storeUrl,
    );
  } catch (e) {
    Loggers.app.warning('Check update failed', e);
    return;
  }

  final result = AppUpdate.version;
  if (result == null) return;

  final newest = result.$1;
  if (newest <= build) return;

  final fileUrl = AppUpdate.url;
  if (fileUrl == null) return;

  final changelog = AppUpdate.changelog;
  final releasesWeb = '${Urls.thisRepo}/releases/latest';

  if (!context.mounted) return;
  final size = MediaQuery.sizeOf(context);

  await context.showRoundDialog(
    title: 'v1.0.$newest 可用',
    child: SizedBox(
      width: size.width * 0.85,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 下载地址
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('下载地址', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SelectableText(fileUrl, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 更新日志
          if (changelog != null && changelog.isNotEmpty)
            SimpleMarkdown(data: changelog)
          else
            Text('暂无更新说明', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => context.pop(), // 跳过此版本
        child: const Text('跳过此版本', style: TextStyle(color: Colors.grey)),
      ),
      TextButton(
        onPressed: () async {
          await releasesWeb.launchUrl();
        },
        child: const Text('一键直达'),
      ),
      TextButton(
        onPressed: () {
          context.pop();
          fileUrl.launchUrl();
        },
        child: const Text('更新'),
      ),
    ],
  );
}
