import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/player_identity.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_controller.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/progression.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_error.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/profile/views/player_profile_panel.dart';
import 'package:kolkhoz_app/src/app/views/shared/rule_content.dart';
import '../main_menu_view.dart';

part 'admin_operations_view.dart';
part 'cloud_auth_view.dart';
part 'comrades_view.dart';
part 'profile_view.dart';
part 'rules_view.dart';

const maxAccountEmailLength = 254;

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.tokens,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLength = 24,
    this.onChanged,
  });

  final DesignTokens tokens;
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool autocorrect;
  final bool enableSuggestions;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.34)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        maxLength: maxLength,
        onChanged: onChanged,
        minLines: 1,
        maxLines: 1,
        style: kolkhozFontStyle.copyWith(
          color: tokens.colors.cream,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          labelStyle: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

class _ProfilePortraitChoice extends StatelessWidget {
  const _ProfilePortraitChoice({
    required this.tokens,
    required this.asset,
    required this.selected,
    required this.unlocked,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String asset;
  final bool selected;
  final bool unlocked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: unlocked,
        label: unlocked ? asset : '$asset (locked)',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: unlocked ? 1 : 0.42,
              child: PlayerProfilePortraitImage(
                tokens: tokens,
                asset: asset,
                size: 58,
                selected: selected,
              ),
            ),
            if (!unlocked)
              Image.asset(
                'assets/ui/Icons/icon-lock.png',
                width: 22,
                height: 22,
                filterQuality: FilterQuality.none,
              ),
          ],
        ),
      ),
    );
  }
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({
    required this.tokens,
    required this.title,
    required this.body,
  });

  final DesignTokens tokens;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tokens.colors.steel.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            title.toUpperCase(),
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.gold,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            body,
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.creamDim,
              fontSize: 15,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class MainMenuGoldDivider extends StatelessWidget {
  const MainMenuGoldDivider({super.key, required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: tokens.colors.gold.withValues(alpha: 0.35),
    );
  }
}

class MainMenuAssetIcon extends StatelessWidget {
  const MainMenuAssetIcon(
    this.asset, {
    super.key,
    this.size = 18,
    this.opacity = 1,
  });

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}
