import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class MediaIcons {
  static IconData resolve(String name) => switch (name) {
        'image' => LucideIcons.image,
        'video' => LucideIcons.video,
        'rotate3d' => LucideIcons.rotate3d,
        'plane' => LucideIcons.plane,
        'layout' => LucideIcons.layout,
        'hardHat' => LucideIcons.hardHat,
        'fileText' => LucideIcons.fileText,
        'map' => LucideIcons.map,
        _ => LucideIcons.film,
      };
}
