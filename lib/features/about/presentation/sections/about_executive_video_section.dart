import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_executive_welcome_section.dart';

/// About-page executive video band — sits above the WHO WE ARE intro.
class AboutExecutiveVideoSection extends StatelessWidget {
  const AboutExecutiveVideoSection({super.key, required this.executiveVideo});

  final AboutExecutiveVideo executiveVideo;

  @override
  Widget build(BuildContext context) {
    final message = executiveVideo.message.trim();
    final video = executiveVideo.videoUrl?.trim() ?? '';
    if (message.isEmpty && video.isEmpty) return const SizedBox.shrink();
    return HomeExecutiveWelcomeSection(
      executive: HomeExecutiveWelcome(
        name: executiveVideo.speakerName,
        title: executiveVideo.speakerTitle,
        message: executiveVideo.message,
        videoUrl: executiveVideo.videoUrl,
      ),
    );
  }
}
