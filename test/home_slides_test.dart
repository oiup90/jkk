import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_home_slides.dart';
import 'package:growth_circle/home_slides.dart';
import 'package:growth_circle/main.dart' show growthTheme;
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSlides extends HomeSlidesGateway {
  FakeSlides(super.client);
  final rows = <HomeSlide>[...HomeSlide.defaults];
  @override
  Future<List<HomeSlide>> load({bool admin = false}) async =>
      List.of(admin ? rows : rows.where((s) => s.enabled));
  @override
  Future<void> add(String title, String mime, Uint8List bytes) async {
    rows.add(
      HomeSlide(
        id: 'uploaded',
        kind: 'image',
        title: title,
        image: bytes,
        mime: mime,
      ),
    );
  }

  @override
  Future<void> setEnabled(HomeSlide slide, bool value) async {
    final i = rows.indexWhere((s) => s.id == slide.id);
    rows[i] = HomeSlide(
      id: slide.id,
      kind: slide.kind,
      title: slide.title,
      image: slide.image,
      mime: slide.mime,
      enabled: value,
    );
  }

  @override
  Future<void> delete(HomeSlide slide) async =>
      rows.removeWhere((s) => s.id == slide.id);
  @override
  Future<void> move(HomeSlide slide, int direction) async {
    final index = rows.indexWhere((s) => s.id == slide.id);
    final item = rows.removeAt(index);
    rows.insert(index + direction, item);
  }
}

void main() {
  testWidgets('home slides navigate, rotate, and honor disabled motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var referral = 0, earn = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: HomeSlideshow(
            onReferral: () => referral++,
            onEarnings: () => earn++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Invite friends'), findsOneWidget);
    await tester.tap(find.text('Invite friends'));
    expect(referral, 1);
    await tester.drag(find.byType(PageView), const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(find.text('Earn from tasks'), findsOneWidget);
    await tester.tap(find.text('Earn from tasks'));
    expect(earn, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'slideshow refreshes admin changes and pauses for reduced motion',
    (tester) async {
      var visible = <HomeSlide>[...HomeSlide.defaults];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: HomeSlideshow(load: () async => List.of(visible)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Invite friends'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Invite friends'), findsOneWidget);
      visible = [HomeSlide.defaults.last];
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(find.text('Earn from tasks'), findsOneWidget);
      expect(find.text('Invite friends'), findsNothing);
      visible = [];
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(find.byType(PageView), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('admin manages slides and downloads built in and uploaded art', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = SupabaseClient(
      'https://example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(() {
      client.dispose();
    });
    final gateway = FakeSlides(client);
    final image = (await rootBundle.load('assets/design/brand_logo.png')).buffer
        .asUint8List();
    final saved = <Uint8List>[];
    var verifications = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminHomeSlidesPage(
          client: client,
          canEdit: true,
          gateway: gateway,
          verifyChange: () async {
            verifications++;
            return true;
          },
          chooseImage: () async => XFile.fromData(image, name: 'sample.png'),
          saveImage: (bytes, extension) async {
            expect(extension, 'png');
            saved.add(bytes);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Slide title'),
      'My slide',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose image'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
      find.text('Image selected'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | '),
    );
    await tester.tap(find.text('Add slide').last);
    await tester.pumpAndSettle();
    expect(gateway.rows.length, 3);
    expect(verifications, 1);
    await tester.scrollUntilVisible(
      find.text('My slide'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final card = find
        .ancestor(of: find.text('My slide'), matching: find.byType(Card))
        .first;
    await tester.tap(
      find.descendant(of: card, matching: find.text('Download')),
    );
    await tester.pumpAndSettle();
    expect(saved.single, image);
    await tester.tap(find.descendant(of: card, matching: find.text('Hide')));
    await tester.pumpAndSettle();
    expect(gateway.rows.last.enabled, false);
    await tester.scrollUntilVisible(
      find.text('Referral rewards'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final builtin = find
        .ancestor(
          of: find.text('Referral rewards'),
          matching: find.byType(Card),
        )
        .first;
    await tester.runAsync(() async {
      await tester.tap(
        find.descendant(of: builtin, matching: find.text('Download')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(saved.last.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('viewer can download but cannot mutate', (tester) async {
    final client = SupabaseClient(
      'https://example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(() {
      client.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AdminHomeSlidesPage(
          client: client,
          canEdit: false,
          gateway: FakeSlides(client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add slide'), findsNothing);
    expect(find.text('Hide'), findsNothing);
    expect(find.text('Download'), findsWidgets);
  });
}
