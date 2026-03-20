import 'package:flutter/material.dart';
import '../theme.dart';

class AccentButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double height;

  const AccentButton(
      {super.key,
      required this.onPressed,
      required this.child,
      this.height = 44});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: child,
      ),
    );
  }
}
