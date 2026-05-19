import 'package:csv/csv.dart';

void main() {
  var converter = ListToCsvConverter();
  print(converter.convert([["a", "b"]]));
}
