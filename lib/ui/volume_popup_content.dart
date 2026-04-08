import 'package:flutter/material.dart';

class VolumePopupContent extends StatefulWidget {
  final GlobalKey buttonKey;
  final double currentVolume;
  final Function(double) onVolumeChanged;
  final VoidCallback onClose;

  const VolumePopupContent({
    super.key,
    required this.buttonKey,
    required this.currentVolume,
    required this.onVolumeChanged,
    required this.onClose,
  });

  @override
  State<VolumePopupContent> createState() => _VolumePopupContentState();
}

class _VolumePopupContentState extends State<VolumePopupContent> {
  double currentVolume = 0;

  @override
  void initState() {
    super.initState();

    currentVolume = widget.currentVolume;
    // 延迟一帧执行，确保按钮已经渲染完成，能获取到位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPopup();
    });
  }

  void _showPopup() {
    final RenderBox buttonRenderBox =
        widget.buttonKey.currentContext!.findRenderObject() as RenderBox;
    final buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // 计算弹窗位置：显示在按钮正下方
    double top =
        buttonPosition.dy + buttonRenderBox.size.height + 10; // 10px 间距
    double left = buttonPosition.dx +
        (buttonRenderBox.size.width / 2) -
        100; // 假设弹窗宽200，居中

    // 边界检查：如果下方空间不足，则显示在上方
    if (top + 200 > screenSize.height) {
      top = buttonPosition.dy - 210; // 200高度 + 10间距
    }

    // 左右边界检查
    if (left < 0) left = 10;
    if (left + 200 > screenSize.width) left = screenSize.width - 210;

    // 使用 Stack + Positioned 来精确定位
    // 注意：这里我们需要重新构建一个包含 Positioned 的 Stack 覆盖全屏
    // 但 OverlayEntry 的 builder 返回的已经是全屏堆叠了，我们直接返回一个 Stack 即可
  }

  @override
  Widget build(BuildContext context) {
    // 获取按钮位置
    if (widget.buttonKey.currentContext == null) return const SizedBox.shrink();

    final RenderBox buttonRenderBox =
        widget.buttonKey.currentContext!.findRenderObject() as RenderBox;
    final buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // 计算位置逻辑
    double top = buttonPosition.dy + buttonRenderBox.size.height + 8;
    double popupWidth = 200.0;
    double popupHeight = 160.0;

    // 默认居中于按钮
    double left =
        buttonPosition.dx + (buttonRenderBox.size.width - popupWidth) / 2;

    // 底部溢出处理 -> 显示在上方
    if (top + popupHeight > screenSize.height) {
      top = buttonPosition.dy - popupHeight - 8;
    }
    // 左侧溢出处理
    if (left < 0) left = 8;
    // 右侧溢出处理
    if (left + popupWidth > screenSize.width) {
      left = screenSize.width - popupWidth - 8;
    }

    return GestureDetector(
      // 点击背景关闭
      behavior: HitTestBehavior.translucent,
      onTap: widget.onClose,
      child: Stack(
        children: [
          // 半透明遮罩 (可选)
          Container(color: Colors.black.withOpacity(0.3)),

          Positioned(
            left: left,
            top: top,
            width: popupWidth,
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {}, // 防止点击弹窗内部触发外部的 GestureDetector
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("音量",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: widget.onClose,
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text("${(currentVolume * 100).toInt()}%",
                          style: Theme.of(context).textTheme.titleMedium),
                      Slider(
                        value: currentVolume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        onChanged: onSlideValueChanged,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void onSlideValueChanged(double val) {
    setState(() {
      currentVolume = val;
    });

    widget.onVolumeChanged(val);
  }
}
