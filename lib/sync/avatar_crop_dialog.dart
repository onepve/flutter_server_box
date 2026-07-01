import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 圆形头像裁剪对话框
///
/// 用户可缩放/拖动图片，选择圆形区域后确认裁剪上传。
class AvatarCropDialog extends StatefulWidget {
  final File imageFile;
  final double cropSize;

  const AvatarCropDialog({
    super.key,
    required this.imageFile,
    this.cropSize = 280,
  });

  /// 弹出裁剪对话框，返回裁剪后的 PNG 字节数据（或 null 表示取消）
  static Future<Uint8List?> show(BuildContext context, File imageFile) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AvatarCropDialog(imageFile: imageFile),
    );
  }

  @override
  State<AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<AvatarCropDialog> {
  final TransformationController _transformCtrl = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  bool _isCropping = false;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  /// 用 RepaintBoundary 捕获当前圆形区域为图片
  Future<Uint8List> _captureCrop() async {
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('渲染节点未就绪，请重试');

    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final size = boundary.size;
    final half = size.shortestSide / 2;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 将中心圆形区域裁剪出来
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final clipRect = Rect.fromLTWH(cx - half, cy - half, half * 2, half * 2);
    canvas.clipRRect(RRect.fromRectAndRadius(clipRect, Radius.circular(half)));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      clipRect,
      Paint(),
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(half.toInt() * 2, half.toInt() * 2);

    final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    cropped.dispose();
    picture.dispose();
    return byteData!.buffer.asUint8List();
  }

  Future<void> _onConfirm() async {
    setState(() => _isCropping = true);
    try {
      final bytes = await _captureCrop();
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('裁剪失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final cropSize = widget.cropSize.clamp(200.0, screenSize.width - 40);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 标题 ──
            Row(
              children: [
                const Icon(Icons.crop_square, size: 18),
                const SizedBox(width: 8),
                Text(
                  '调整头像',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '拖动/缩放图片，选择圆形区域',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),

            // ── 裁剪区域 ──
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: cropSize,
                height: cropSize,
                child: Stack(
                  children: [
                    // 可缩放拖动的图片（包在 RepaintBoundary 内以便截图）
                    RepaintBoundary(
                      key: _repaintKey,
                      child: ClipOval(
                        child: SizedBox(
                          width: cropSize,
                          height: cropSize,
                          child: InteractiveViewer(
                            transformationController: _transformCtrl,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.file(
                              widget.imageFile,
                              width: cropSize,
                              height: cropSize,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 遮罩层：半透明背景 + 圆形透明区域
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(cropSize, cropSize),
                        painter: _CropMaskPainter(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 操作按钮 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isCropping ? null : () => Navigator.of(context).pop(null),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isCropping ? null : _onConfirm,
                  child: _isCropping
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('确认上传'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 圆形裁剪遮罩绘制器
class _CropMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    // 半透明遮罩 + 圆形挖空
    final paint = Paint()..color = Colors.black54;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // 圆形白色边框（指示裁剪区域）
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
