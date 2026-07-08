import 'app_settings.dart';
import 'app_text.dart';
import 'render_model.dart';

String hotSeatPhaseLine(TableViewModel model, {KolkhozLanguage? language}) {
  final resolvedLanguage = language ?? KolkhozLanguage.en;
  final phaseName = resolvedLanguage.phaseName(model.table.phase);
  return resolvedLanguage.t(KolkhozText.phasedisplayYearValue1Phasename, {
    'value1': model.table.year,
    'phaseName': phaseName,
  });
}
