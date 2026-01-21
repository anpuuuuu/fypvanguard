// lib/utils/string_extensions.dart

extension StringExtensions on String {
  /// Capitalizes the first letter of the string.
  ///
  /// Returns the original string if it is empty.
  String capitalize() {
    return isEmpty ? '' : this[0].toUpperCase() + substring(1);
  }
}
