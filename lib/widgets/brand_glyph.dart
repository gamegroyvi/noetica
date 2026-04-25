import 'package:flutter/material.dart';

/// Brand pentagon glyph — used as sidebar logo and AppBar leading.
/// The asset is white-bordered + black-filled, so it works on both light
/// and dark backgrounds without colour filters.
class BrandGlyph extends StatelessWidget {
  const BrandGlyph({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/branding/tray_icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
