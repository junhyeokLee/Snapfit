import 'package:flutter/material.dart';
import 'package:page_flip/page_flip.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: PageFlipWidget(
          key: GlobalKey<PageFlipWidgetState>(),
          backgroundColor: Colors.white,
          initialIndex: 0,
          lastPage: Container(color: Colors.white, child: const Center(child: Text('Last Page'))),
          children: [
            for (var i = 0; i < 5; i++)
              Container(
                color: Colors.primaries[i % Colors.primaries.length],
                child: Center(child: Text('Page $i', style: const TextStyle(fontSize: 40, color: Colors.white))),
              ),
          ],
        ),
      ),
    );
  }
}
