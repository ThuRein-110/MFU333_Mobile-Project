import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/l10n/app_language.dart';
import 'package:frontend/widgets/activity_date_time_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'calendar fields validate order, display local dates, and retain UTC API values',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final language = AppLanguage();
      await language.select('en');
      final start = TextEditingController(text: '2026-11-17T10:00:00Z');
      final end = TextEditingController(text: '2026-11-17T09:00:00Z');
      final form = GlobalKey<FormState>();
      var valid = false;
      await tester.pumpWidget(
        AppLanguageScope(
          controller: language,
          child: MaterialApp(
            home: Scaffold(
              body: Form(
                key: form,
                child: Column(
                  children: [
                    ActivityDateTimeField(controller: start, label: 'Start'),
                    ActivityDateTimeField(
                      controller: end,
                      label: 'End',
                      after: start,
                    ),
                    FilledButton(
                      onPressed: () => valid = form.currentState!.validate(),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).readOnly,
        isTrue,
      );
      expect(find.text('2026-11-17T10:00:00Z'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(valid, isFalse);
      expect(find.text('End time must be after start time'), findsOneWidget);
      end.text = '2026-11-17T11:00:00Z';
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(valid, isTrue);
      await tester.tap(find.byIcon(Icons.calendar_month).first);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(DateTime.parse(start.text), DateTime.utc(2026, 11, 17, 10));
      expect(start.text.endsWith('Z'), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      start.dispose();
      end.dispose();
      language.dispose();
    },
  );
}
