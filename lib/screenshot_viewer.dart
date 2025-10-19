import 'package:flutter/material.dart';

class ScreenshotViewer extends StatelessWidget {
  const ScreenshotViewer({super.key});

  static const _images = [
    'assets/img/logo.png',
    'assets/img/mission-3.jpg',
    'assets/img/mission-4.jpg',
    'assets/img/home1-img.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screenshots'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: _images.length,
        itemBuilder: (context, idx) {
          final img = _images[idx];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _FullScreenImage(image: img),
              ));
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(img, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String image;
  const _FullScreenImage({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          child: Image.asset(image),
        ),
      ),
    );
  }
}
