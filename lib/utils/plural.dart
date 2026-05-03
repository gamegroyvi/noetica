/// Russian pluralization helper.
///
/// Returns [one] for 1, 21, 31… (except 11, 111…),
/// [few] for 2–4, 22–24… (except 12–14), and [many] for the rest.
String plural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}
