import 'dart:convert';

import 'package:flutter/services.dart';

import 'contracts.dart';
import 'design_tokens.dart';

const fixtureAssetRoot = 'shared/app-contracts/fixtures';
const tokenAssetPath = 'shared/design/tokens.json';

const fixtureAssetPaths = [
  '$fixtureAssetRoot/planning_trump_selection.json',
  '$fixtureAssetRoot/assignment_pending.json',
  '$fixtureAssetRoot/online_redacted_swap.json',
];

class FixtureBundle {
  const FixtureBundle({required this.tokens, required this.fixtures});

  final DesignTokens tokens;
  final List<NamedFixture> fixtures;
}

class NamedFixture {
  const NamedFixture({required this.name, required this.model});

  final String name;
  final TableViewModel model;
}

class FixtureRepository {
  FixtureRepository({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  final AssetBundle bundle;

  Future<FixtureBundle> load() async {
    final tokenJson =
        jsonDecode(await bundle.loadString(tokenAssetPath))
            as Map<String, Object?>;
    final fixtures = <NamedFixture>[];
    for (final path in fixtureAssetPaths) {
      final json =
          jsonDecode(await bundle.loadString(path)) as Map<String, Object?>;
      fixtures.add(
        NamedFixture(
          name: _fixtureName(path),
          model: TableViewModel.fromJson(json),
        ),
      );
    }
    return FixtureBundle(
      tokens: DesignTokens.fromJson(tokenJson),
      fixtures: fixtures,
    );
  }

  String _fixtureName(String path) {
    return path.split('/').last.replaceAll('.json', '').replaceAll('_', ' ');
  }
}
