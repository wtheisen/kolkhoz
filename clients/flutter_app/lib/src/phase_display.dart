import 'app_settings.dart';
import 'render_model.dart';

String hotSeatPhaseLine(TableViewModel model, {KolkhozLanguage? language}) {
  final resolvedLanguage = language ?? KolkhozLanguage.en;
  final phaseName = resolvedLanguage.phaseName(model.table.phase);
  return resolvedLanguage.text(
    en: 'Year ${model.table.year} - $phaseName',
    ru: 'Год ${model.table.year} - $phaseName',
  );
}
