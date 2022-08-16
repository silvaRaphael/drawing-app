import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:draw_app/models/drawn_line.dart';
import 'package:draw_app/models/sketcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class DrawingPage extends StatefulWidget {
  const DrawingPage({Key? key}) : super(key: key);

  @override
  _DrawingPageState createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  final GlobalKey _globalKey = GlobalKey();
  List<DrawnLine> lines = <DrawnLine>[];
  DrawnLine line = DrawnLine([], Colors.transparent, 0);
  Color selectedColor = Colors.red;
  double selectedWidth = 5;

  StreamController<List<DrawnLine>> linesStreamController =
      StreamController<List<DrawnLine>>.broadcast();
  StreamController<DrawnLine> currentLineStreamController =
      StreamController<DrawnLine>.broadcast();

  @override
  void initState() {
    super.initState();
    clear();
  }

  Future<void> save() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage();
      ByteData byteData =
          await image.toByteData(format: ui.ImageByteFormat.png) as ByteData;
      Uint8List pngBytes = byteData.buffer.asUint8List();
      await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: "${DateTime.now().toIso8601String()}.png",
        isReturnImagePathOfIOS: true,
      );
      showMySnackBar(true);
    } catch (e) {
      showMySnackBar(false);
    }
  }

  void showMySnackBar(bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: success
            ? const Text('Imagem salva!')
            : const Text('Houve um erro!'),
        action: SnackBarAction(
          textColor: Colors.white,
          label: 'Ok',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        backgroundColor: success ? Colors.greenAccent[700] : Colors.redAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }

  Future<void> clear() async {
    setState(() {
      lines = [
        DrawnLine([
          Offset(MediaQuery.of(context).size.width / 2, 0),
          Offset(MediaQuery.of(context).size.width / 2,
              MediaQuery.of(context).size.height),
        ], Colors.white, MediaQuery.of(context).size.width),
      ];
      line = DrawnLine([], Colors.transparent, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          buildAllPaths(context),
          buildCurrentPath(context),
          buildStrokeToolbar(),
          buildColorToolbar(),
        ],
      ),
    );
  }

  Widget buildCurrentPath(BuildContext context) {
    void onPanStart(DragStartDetails details) {
      RenderBox box = context.findRenderObject() as RenderBox;
      Offset point = box.globalToLocal(details.globalPosition);
      line = DrawnLine([point], selectedColor, selectedWidth);
    }

    void onPanUpdate(DragUpdateDetails details) {
      RenderBox box = context.findRenderObject() as RenderBox;
      Offset point = box.globalToLocal(details.globalPosition);

      List<Offset> path = List.from(line.path)..add(point);
      line = DrawnLine(path, selectedColor, selectedWidth);
      currentLineStreamController.add(line);
    }

    void onPanEnd(DragEndDetails details) {
      lines = List.from(lines)..add(line);

      linesStreamController.add(lines);
    }

    return GestureDetector(
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: RepaintBoundary(
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.all(4),
          color: Colors.transparent,
          alignment: Alignment.topLeft,
          child: StreamBuilder<DrawnLine>(
            stream: currentLineStreamController.stream,
            builder: (context, snapshot) {
              return CustomPaint(
                painter: Sketcher(
                  lines: [line],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildAllPaths(BuildContext context) {
    return RepaintBoundary(
      key: _globalKey,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.transparent,
        padding: const EdgeInsets.all(4),
        alignment: Alignment.topLeft,
        child: StreamBuilder<List<DrawnLine>>(
          stream: linesStreamController.stream,
          builder: (context, snapshot) {
            return CustomPaint(
              painter: Sketcher(
                lines: lines,
              ),
            );
          },
        ),
      ),
    );
  }

  bool sizeSliderVisible = false;

  Widget buildStrokeToolbar() {
    return Positioned(
      bottom: 56,
      right: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          buildStrokeButton(5),
          buildStrokeButton(10),
          buildStrokeButton(15),
          Column(
            children: [
              sizeSliderVisible
                  ? RotatedBox(
                      quarterTurns: -1,
                      child: SizedBox(
                        height: 40,
                        child: CupertinoSlider(
                          value: selectedWidth,
                          onChanged: (double value) {
                            setState(() {
                              selectedWidth = value;
                            });
                          },
                          min: 1,
                          max: 100,
                          divisions: 100,
                          activeColor: selectedColor == Colors.white
                              ? Colors.deepOrange
                              : selectedColor,
                        ),
                      ),
                    )
                  : Container(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    sizeSliderVisible = !sizeSliderVisible;
                  });
                },
                child: const CircleAvatar(
                  backgroundColor: Colors.deepOrange,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          buildSaveButton(),
        ],
      ),
    );
  }

  Widget buildStrokeButton(double strokeWidth) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedWidth = strokeWidth;
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          width: strokeWidth * 2,
          height: strokeWidth * 2,
          decoration: BoxDecoration(
            color: selectedColor,
            borderRadius: BorderRadius.circular(50),
            border: selectedColor == Colors.white
                ? Border.all(
                    width: 1,
                    color: Colors.deepOrange,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget buildColorToolbar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildClearButton(),
              const SizedBox(width: 6),
              buildColorButton(Colors.red),
              buildColorButton(Colors.blue),
              buildColorButton(Colors.black),
              buildColorButton(Colors.white),
              const SizedBox(width: 6),
              buildCustomColorPickerButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildColorButton(Color color) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: FloatingActionButton(
        mini: true,
        backgroundColor: color,
        elevation: selectedColor == color ? 1 : 4,
        child: Container(),
        onPressed: () {
          setState(() {
            selectedColor = color;
          });
        },
      ),
    );
  }

  Widget buildSaveButton() {
    return GestureDetector(
      onTap: save,
      child: const CircleAvatar(
        backgroundColor: Colors.deepOrange,
        child: Icon(
          Icons.save,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildClearButton() {
    return GestureDetector(
      onTap: clear,
      child: const CircleAvatar(
        backgroundColor: Colors.deepOrange,
        child: Icon(
          Icons.delete_outline,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  Color pickerColor = const Color(0xff443a49);
  void changeColor(Color color) {
    setState(() => pickerColor = color);
  }

  Widget buildCustomColorPickerButton() {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => AlertDialog(
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: selectedColor,
                onColorChanged: changeColor,
                hexInputBar: false,
                labelTypes: const [],
                paletteType: PaletteType.hueWheel,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MaterialButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      child: const Text('Ok'),
                      onPressed: () {
                        setState(() {
                          selectedColor = pickerColor;
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(.7),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: CircleAvatar(
          backgroundColor: selectedColor,
          child: Icon(
            Icons.palette_outlined,
            size: 20,
            color: selectedColor == Colors.white ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
