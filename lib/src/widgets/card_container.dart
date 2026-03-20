import 'package:flutter/material.dart';
import '../theme.dart';

class CardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const CardContainer(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(12),
      this.margin = const EdgeInsets.symmetric(vertical: 12, horizontal: 18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}
