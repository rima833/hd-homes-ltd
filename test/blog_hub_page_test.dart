import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/blog/presentation/pages/blog_article_page.dart';
import 'package:hdhomesproject/features/blog/presentation/pages/blog_hub_page.dart';

void main() {
  testWidgets('Blog hub loads live CMS sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 7200));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SingleChildScrollView(child: BlogHubPage())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.textContaining('Insights That Build Better Decisions'),
      findsOneWidget,
    );
    expect(find.text('Featured stories'), findsOneWidget);
    expect(find.text('Latest articles'), findsOneWidget);
    expect(find.text('Need advice on a property decision?'), findsOneWidget);
    expect(find.text('Browse by topic'), findsNothing);
    expect(find.text('Trending content'), findsNothing);
    expect(find.text('Live market dashboard'), findsNothing);
    expect(find.text('HD Homes Learning Academy'), findsNothing);
    expect(find.text('Market Reports'), findsNothing);
    expect(find.text('Investment Guides'), findsNothing);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Blog article page loads detail sections', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 4800));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: BlogArticlePage(slug: 'first-time-buyers-guide-nigeria-2026'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('First-Time Buyer'), findsWidgets);
    expect(find.text('Browse all articles'), findsOneWidget);
    expect(find.text('Summarize this article'), findsNothing);
    expect(find.text('Join the discussion'), findsNothing);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Blog article shows not found for invalid slug', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: BlogArticlePage(slug: 'invalid-article'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Article not found'), findsOneWidget);
    expect(find.text('Browse articles'), findsOneWidget);
  });
}
