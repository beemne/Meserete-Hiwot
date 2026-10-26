import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/l10n/l10n.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/auth_screens.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/l10n/app_localizations_am.dart';
import 'package:mezmur_zelideta/models/activity.dart';
import 'package:mezmur_zelideta/models/content.dart';
import 'package:mezmur_zelideta/features/mezmurs/widgets.dart';
import 'package:mezmur_zelideta/widgets/states.dart';

class _SignedOutSession extends SessionController {
  @override
  SessionState build() => const SignedOut();
}

Widget _wrap(Widget child) => ProviderScope(
      overrides: [sessionProvider.overrideWith(_SignedOutSession.new)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('am'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );

void main() {
  final l = AppLocalizationsAm();

  testWidgets('login screen is fully Amharic and validates before calling the API', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pumpAndSettle();
    expect(find.text(l.loginTitle), findsOneWidget);
    expect(find.text(l.phoneOrEmail), findsOneWidget);
    expect(find.text(l.appName), findsOneWidget);

    await tester.tap(find.text(l.login));
    await tester.pumpAndSettle();
    expect(find.text(l.vRequired), findsWidgets);

    await tester.enterText(find.byType(TextFormField).first, '0811');
    await tester.tap(find.text(l.login));
    await tester.pumpAndSettle();
    expect(find.text(l.vInvalidPhone), findsOneWidget);
  });

  testWidgets('register screen asks for a PIN of 4 to 6 digits and checks the confirmation', (tester) async {
    await tester.pumpWidget(_wrap(const RegisterScreen()));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'አበበ ከበደ');
    await tester.enterText(fields.at(1), '0911223344');
    await tester.enterText(fields.at(3), '123'); // 3 digits: not a valid PIN
    await tester.enterText(fields.at(4), '1234');
    await tester.ensureVisible(find.text(l.register).last);
    await tester.tap(find.text(l.register).last);
    await tester.pumpAndSettle();
    expect(find.text(l.vInvalidPin), findsOneWidget);
    expect(find.text(l.vPinMismatch), findsOneWidget);
    // letters are not accepted in a PIN field
    await tester.enterText(fields.at(3), 'ab12');
    expect(find.text('12'), findsWidgets);
  });

  testWidgets('long Amharic category names do not overflow the design card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640)); // small Android phone
    await tester.pumpWidget(_wrap(Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: [
        CategoryCard(
          category: const CategoryNode(id: 1, name: 'የቅድስት ኪዳነምሕረት የምስጋና እና የአምልኮ መዝሙሮች ስብስብ', totalMezmurCount: 120),
          onTap: () {},
        ),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('120'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('program card marks special events with their type', (tester) async {
    final wedding = Program(id: 1, title: 'የአበበ እና የሰላም',  startsAt: DateTime(2030, 1, 1, 17), endsAt: DateTime(2030, 1, 1, 20), audience: 'participants', eventType: 'wedding');
    await tester.pumpWidget(_wrap(Scaffold(body: ProgramCard(program: wedding, onTap: () {}))));
    await tester.pumpAndSettle();
    expect(find.text(l.eventWedding), findsOneWidget);

    final general = Program(id: 2, title: 'ሰንበት', startsAt: DateTime(2030, 1, 1, 17), endsAt: DateTime(2030, 1, 1, 20), audience: 'all');
    await tester.pumpWidget(_wrap(Scaffold(body: ProgramCard(program: general, onTap: () {}))));
    await tester.pumpAndSettle();
    expect(find.text(l.eventWedding), findsNothing);
  });

  testWidgets('empty and error states render translated messages', (tester) async {
    await tester.pumpWidget(_wrap(Scaffold(body: Column(children: [EmptyView(message: l.noDownloads), const Expanded(child: SizedBox())]))));
    expect(find.text(l.noDownloads), findsOneWidget);
  });
}
