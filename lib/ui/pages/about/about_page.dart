import 'package:flutter/material.dart';
import '../../../core/about_data.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hasLogo = AboutData.logoAsset != null && AboutData.logoAsset!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Apresentação')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasLogo)
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundImage: AssetImage(AboutData.logoAsset!),
              ),
            ),
          if (hasLogo) const SizedBox(height: 16),
          Text(
            AboutData.appName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            AboutData.description,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Autor(a)'),
            subtitle: Text(AboutData.author),
          ),
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('Contato'),
            subtitle: Text(AboutData.contact),
          ),
          ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('Versão'),
            subtitle: Text(AboutData.version),
          ),
        ],
      ),
    );
  }
}
