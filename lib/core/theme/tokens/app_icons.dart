import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Icon conventions — Material Symbols Rounded primary, Lucide supplement.
abstract final class AppIcons {
  // Navigation
  static const IconData home = Icons.home_rounded;
  static const IconData menu = Icons.menu_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData back = Icons.arrow_back_rounded;

  // Property
  static const IconData property = LucideIcons.building2;
  static const IconData location = LucideIcons.mapPin;
  static const IconData bed = LucideIcons.bedDouble;
  static const IconData bath = LucideIcons.bath;
  static const IconData area = LucideIcons.maximize2;
  static const IconData favorite = Icons.favorite_rounded;
  static const IconData favoriteOutline = Icons.favorite_border_rounded;

  // Actions
  static const IconData add = Icons.add_rounded;
  static const IconData edit = LucideIcons.pencil;
  static const IconData delete = LucideIcons.trash2;
  static const IconData download = LucideIcons.download;
  static const IconData upload = LucideIcons.upload;
  static const IconData share = LucideIcons.share2;
  static const IconData filter = LucideIcons.slidersHorizontal;

  // Status
  static const IconData success = Icons.check_circle_rounded;
  static const IconData warning = Icons.warning_rounded;
  static const IconData error = Icons.error_rounded;
  static const IconData info = Icons.info_rounded;

  // User
  static const IconData user = Icons.person_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData logout = LucideIcons.logOut;
  static const IconData notification = Icons.notifications_rounded;

  // Finance
  static const IconData payment = LucideIcons.creditCard;
  static const IconData receipt = LucideIcons.receipt;

  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
}
