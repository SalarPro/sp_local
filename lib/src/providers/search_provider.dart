import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/i18n_models.dart';

/// Search filter state.
final searchProvider = StateProvider<SearchFilter>((ref) {
  return const SearchFilter();
});

/// Sort configuration state.
final sortProvider = StateProvider<SortConfig>((ref) {
  return const SortConfig();
});
