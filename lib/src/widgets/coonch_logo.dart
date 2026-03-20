import 'package:flutter/material.dart';

/// Reusable COONCH logo drawing without relying on bundled image assets.
class CoonchLogo extends StatelessWidget {
  const CoonchLogo({
    super.key,
    this.direction = Axis.vertical,
    this.iconDiameter = 170,
    this.ringStroke = 22,
    this.textSize = 28,
    this.fontWeight = FontWeight.w700,
    this.spacing = 14,
    this.showText = true,
    this.fillColor = _fillColor,
    this.ringColor = _ringColor,
    this.textColor = _ringColor,
  });

  final Axis direction;
  final double iconDiameter;
  final double ringStroke;
  final double textSize;
  final FontWeight fontWeight;
  final double spacing;
  final bool showText;
  final Color fillColor;
  final Color ringColor;
  final Color textColor;

  static const _fillColor = Color.fromRGBO(169, 203, 245, 0.85);
  static const _ringColor = Color.fromRGBO(154, 188, 247, 0.88);

  @override
  Widget build(BuildContext context) {
    final scale = iconDiameter / 170;
    final height = 140 * scale;
    final fill = 124 * scale;
    final ring = 126 * scale;
    final ringStrokeScaled = ringStroke * scale;

    final mark = SizedBox(
      width: iconDiameter,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 10 * scale,
            child: SizedBox(
              width: fill,
              height: fill,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fillColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 6 * scale,
            child: SizedBox(
              width: ring,
              height: ring,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: ringColor, width: ringStrokeScaled),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final items = <Widget>[mark];
    if (showText) {
      items.add(direction == Axis.vertical
          ? SizedBox(height: spacing)
          : SizedBox(width: spacing));
      items.add(Text(
        'COONCH',
        style: TextStyle(
          fontSize: textSize,
          fontWeight: fontWeight,
          letterSpacing: 1,
          color: textColor,
        ),
      ));
    }

    return Flex(
      mainAxisSize: MainAxisSize.min,
      direction: direction,
      children: items,
    );
  }
}
