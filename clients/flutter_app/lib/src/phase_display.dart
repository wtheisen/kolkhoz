import 'app_settings.dart';
import 'render_model.dart';

String phaseDisplayName(String phase, {KolkhozLanguage? language}) {
  return (language ?? KolkhozLanguage.en).phaseName(phase);
}

String yearPhaseLine({
  required int year,
  required String phase,
  KolkhozLanguage? language,
}) {
  final resolvedLanguage = language ?? KolkhozLanguage.en;
  return resolvedLanguage.text(
    en: 'Year $year - ${phaseDisplayName(phase, language: resolvedLanguage)}',
    ru: 'Год $year - ${phaseDisplayName(phase, language: resolvedLanguage)}',
  );
}

String hotSeatPhaseLine(TableViewModel model, {KolkhozLanguage? language}) {
  return yearPhaseLine(
    year: model.table.year,
    phase: model.table.phase,
    language: language,
  );
}
