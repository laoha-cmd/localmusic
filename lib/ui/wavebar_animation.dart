import 'package:flutter/material.dart';

class WaveBarAnimation extends StatefulWidget {
  const WaveBarAnimation({super.key});

  @override
  State<WaveBarAnimation> createState() => _WaveBarAnimationState();
}

class _WaveBarAnimationState extends State<WaveBarAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int barCount = 5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(barCount, (index) {
          return AnimatedBar(
            controller: _controller,
            delay: index * 0.1, // 每个柱子延迟不同，产生流动效果
            index: index,
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class AnimatedBar extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final int index;

  const AnimatedBar({
    super.key,
    required this.controller,
    required this.delay,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // 计算高度：根据延迟产生不同的高度值
        double value = (controller.value + delay) % 1.0;
        double height = 1 + 10 * value; // 最小20，最大60

        return Container(
          width: 2,
          margin: EdgeInsets.symmetric(horizontal: 1),
          height: height,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}
