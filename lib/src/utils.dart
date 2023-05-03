void checkIsJsonAndAsBytesParams(isJson, asBytes) {
  if (isJson && asBytes) {
    throw ArgumentError(
      'It\'s not possible to use isJson and asBytes together.',
    );
  }
}

List<int> retryStatusCodes = [
  408,
  429,
  440,
  460,
  499,
  500,
  502,
  503,
  504,
  520,
  521,
  522,
  523,
  524,
  525,
  527,
  598,
  599
];
