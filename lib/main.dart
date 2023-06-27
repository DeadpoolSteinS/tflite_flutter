import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isWorking = false;
  String result = "";
  late CameraController cameraController;
  CameraImage? imgCamera;

  @override
  void initState() {
    super.initState();
    loadModel();
    initCamera();
  }

  @override
  void dispose() async {
    await Tflite.close();
    cameraController.dispose();
    super.dispose();
  }

  loadModel() async {
    await Tflite.loadModel(
      model: "assets/mobilenet_v1_1.0_224.tflite",
      labels: "assets/mobilenet_v1_1.0_224.txt",
    );
  }

  void initCamera() async {
    final cameras = await availableCameras();
    cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await cameraController.initialize();
    cameraController.startImageStream((CameraImage image) {
      if (!isWorking) {
        setState(() {
          isWorking = true;
          imgCamera = image;
          runModelOnStreamFrames();
        });
      }
    });
  }

  runModelOnStreamFrames() async {
    if (imgCamera != null) {
      var recognitions = await Tflite.runModelOnFrame(
        bytesList: imgCamera!.planes.map((plane) {
          return plane.bytes;
        }).toList(),
        imageHeight: imgCamera!.height,
        imageWidth: imgCamera!.width,
        imageMean: 127.5,
        imageStd: 127.5,
        rotation: 90,
        numResults: 2,
        threshold: 0.1,
        asynch: true,
      );

      result = "";

      if (recognitions != null) {
        for (var element in recognitions) {
          result += element["label"] +
              "  " +
              (element["confidence"] as double).toStringAsFixed(2) +
              "\n\n";
        }
      }

      setState(() {
        result;
      });

      isWorking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  initCamera();
                },
                child: Text('Start Camera'),
              ),
              SizedBox(height: 10),
              if (imgCamera != null)
                Container(
                  child: AspectRatio(
                    aspectRatio: cameraController.value.aspectRatio,
                    child: CameraPreview(cameraController),
                  ),
                ),
              SizedBox(height: 10),
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 55.0),
                  child: SingleChildScrollView(
                    child: Text(
                      result,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
