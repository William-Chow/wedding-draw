import 'dart:math';

import 'package:animated_digit/animated_digit.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      //title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: false,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  // final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final ValueNotifier<num> _numberNotifier;
  late final ValueNotifier<num> _numberTwoNotifier;
  late final ValueNotifier<num> _numberThreeNotifier;
  bool isSpin = false;
  List<String> luckyNumber = ['000'];

  late ConfettiController _controllerCenter;

  void pressNumber() {
    final random = Random();
    setState(() {
      if (!isSpin) {
        isSpin = true;
        _numberThreeNotifier.value = (random.nextInt(10)).toDouble();
        _numberTwoNotifier.value = (random.nextInt(10)).toDouble();
        _numberNotifier.value = (random.nextInt(2)).toDouble();
        var avoidDuplicateNumber =
            '${_numberNotifier.value.toInt()}${_numberTwoNotifier.value.toInt()}${_numberThreeNotifier.value.toInt()}';
        if (!luckyNumber.contains(avoidDuplicateNumber)) {
          luckyNumber.add(avoidDuplicateNumber);
        }
        Future.delayed(const Duration(seconds: 10), () {
          fireworkPlay();
        });
      } else {
        _numberNotifier.value = 0;
        _numberTwoNotifier.value = 0;
        _numberThreeNotifier.value = 0;
        isSpin = false;
        _controllerCenter.stop();
      }
    });
  }

  void fireworkPlay() {
    _controllerCenter.play();
  }

  @override
  void initState() {
    _numberNotifier = ValueNotifier(0);
    _numberTwoNotifier = ValueNotifier(0);
    _numberThreeNotifier = ValueNotifier(0);
    _controllerCenter =
        ConfettiController(duration: const Duration(seconds: 10));
    super.initState();
  }

  @override
  void dispose() {
    _numberNotifier.dispose();
    _numberTwoNotifier.dispose();
    _numberThreeNotifier.dispose();

    _controllerCenter.dispose();
    super.dispose();
  }

  Path drawStar(Size size) {
    // Method to convert degree to radians
    double degToRad(double deg) => deg * (pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step),
          halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  // Task
  //-----------------------------------
  // Sound
  // Number bigger and button on center
  // Number spinning more longer
  // Firework animation

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      // appBar: AppBar(
      //   backgroundColor: Colors.white,
      //   elevation: 0,
      // ),
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _controllerCenter,
                blastDirectionality: BlastDirectionality.explosive,
                // don't specify a direction, blast randomly
                shouldLoop: true,
                // start again as soon as the animation is finished
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
                // manually specify the colors to be used
                createParticlePath: drawStar, // define a custom shape/path.
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: luckyNumber.length,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return const Center(
                            child: Text(
                              'Lucky Number',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.black),
                            ),
                          );
                        }

                        return Card(
                          margin: const EdgeInsets.all(4.0),
                          child: Center(
                            heightFactor: 2,
                            child: Text(luckyNumber[index]),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    flex: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const SizedBox(
                          width: 20,
                        ),
                        AnimatedDigitWidget(
                          value: _numberNotifier.value,
                          duration: !isSpin
                              ? const Duration(seconds: 5)
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          textStyle: const TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(
                          width: 25,
                        ),
                        AnimatedDigitWidget(
                          value: _numberTwoNotifier.value,
                          duration: !isSpin
                              ? const Duration(seconds: 8)
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          textStyle: const TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(
                          width: 25,
                        ),
                        AnimatedDigitWidget(
                          value: _numberThreeNotifier.value,
                          duration: !isSpin
                              ? const Duration(seconds: 10)
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          textStyle: const TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(
                          width: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: pressNumber,
        tooltip: isSpin ? 'Reset' : 'Draw',
        child: const Icon(Icons.ads_click),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
