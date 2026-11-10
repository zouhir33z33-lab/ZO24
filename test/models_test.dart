import 'package:eps_assistant/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Student toMap/fromMap round trip', () {
    const s = Student(classId: 1, firstName: 'A', lastName: 'B', gender: 'F', paiConditions: 'x');
    final m = s.toMap();
    final back = Student.fromMap({...m, 'id': 3});
    expect(back.fullName, 'B A');
    expect(back.hasPai, true);
    expect(back.id, 3);
  });
}
