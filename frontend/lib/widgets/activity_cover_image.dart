import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/api_config.dart';

class ActivityCoverImage extends StatelessWidget {
  const ActivityCoverImage({super.key, required this.url, this.height = 180});
  final String url;
  final double height;

  @override
  Widget build(BuildContext context) => Image.network(
    Uri.parse(ApiConfig.baseUrl).resolve(url).toString(),
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    semanticLabel: context.tr('รูปกิจกรรม'),
    errorBuilder: (_, _, _) => SizedBox(
      height: height,
      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
    ),
  );
}
