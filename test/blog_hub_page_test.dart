import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/blog/presentation/pages/blog_article_page.dart';
import 'package:hdhomesproject/features/blog/presentation/pages/blog_hub_page.dart';

void main() {
  testWidgets('Blog hub loads Knowledge Center sections', (WidgetTester tester) async {
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

    expect(find.textContaining('Insights That Build Better Decisions'), findsOneWidget);
    expect(find.text('Featured stories'), findsOneWidget);
    expect(find.text('Latest articles'), findsOneWidget);
    expect(find.text('Browse by topic'), findsOneWidget);
    expect(find.text('Trending content'), findsOneWidget);
    expect(find.text('Live market dashboard'), findsOneWidget);
    expect(find.text('HD Homes Learning Academy'), findsOneWidget);
    expect(find.text('Meet our experts'), findsOneWidget);
    expect(find.text('Stay ahead of the market'), findsOneWidget);

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
    expect(find.text('Summarize this article'), findsOneWidget);
    expect(find.text('Related articles'), findsOneWidget);
    expect(find.text('Join the discussion'), findsOneWidget);

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
    expect(find.text('Browse Knowledge Center'), findsOneWidget);
  });
}
