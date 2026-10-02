import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

/// Website carousel that keeps center-page scale animation without yellow
/// overflow stripes. Clips paint overflow and pads height for [enlargeFactor].
class ScaleSafeCarousel extends StatelessWidget {
  const ScaleSafeCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.viewportFraction = 0.42,
    this.enlargeFactor = 0.28,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 4),
  });

  final int itemCount;
  final ExtendedIndexedWidgetBuilder itemBuilder;
  final double height;
  final double viewportFraction;
  final double enlargeFactor;
  final bool autoPlay;
  final Duration autoPlayInterval;

  @override
  Widget build(BuildContext context) {
    // Scale enlarges the center slide past [height]; give the viewport room
    // and clip so neighbors never paint overflow banners.
    final viewportHeight = height * (1 + enlargeFactor);

    return SizedBox(
      height: viewportHeight,
      child: ClipRect(
        child: CarouselSlider.builder(
          itemCount: itemCount,
          itemBuilder: (context, index, realIndex) {
            return Align(
              alignment: Alignment.center,
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: itemBuilder(context, index, realIndex),
              ),
            );
          },
          options: CarouselOptions(
            height: viewportHeight,
            viewportFraction: viewportFraction,
            enlargeCenterPage: true,
            enlargeFactor: enlargeFactor,
            enlargeStrategy: CenterPageEnlargeStrategy.scale,
            autoPlay: autoPlay && itemCount > 1,
            autoPlayInterval: autoPlayInterval,
            autoPlayAnimationDuration: const Duration(milliseconds: 700),
            autoPlayCurve: Curves.easeInOutCubic,
            enableInfiniteScroll: itemCount > 1,
            pauseAutoPlayOnTouch: true,
            pauseAutoPlayOnManualNavigate: true,
            scrollPhysics: const BouncingScrollPhysics(),
            padEnds: true,
          ),
        ),
      ),
    );
  }
}
