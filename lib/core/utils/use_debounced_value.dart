import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';

/// Returns a debounced version of [value].
///
/// The returned value only updates after [delay] has passed since the last
/// change to [value]. This prevents rapid-fire updates (e.g., per keystroke)
/// from triggering expensive operations like Supabase queries.
///
/// Usage:
/// ```dart
/// final searchQuery = useState('');
/// final debouncedQuery = useDebouncedValue(searchQuery.value);
/// final results = ref.watch(someProvider(search: debouncedQuery));
/// ```
String useDebouncedValue(
  String value, {
  Duration delay = const Duration(milliseconds: 350),
}) {
  final debouncedValue = useState(value);
  final timer = useRef<Timer?>(null);

  useEffect(() {
    if (value == debouncedValue.value) return null;

    timer.value?.cancel();
    timer.value = Timer(delay, () {
      debouncedValue.value = value;
    });

    return () => timer.value?.cancel();
  }, [value]);

  return debouncedValue.value;
}
