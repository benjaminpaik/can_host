import 'dart:async';
import 'dart:isolate';
import 'package:can_host/definitions.dart';
import 'package:can_host/misc/config_data.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

import '../misc/file_utilities.dart';
import '../protocol/can_protocol.dart';

class FileModel extends ChangeNotifier {

  final CANApi _can;
  final ConfigData _configData;

  bool _saveByteFile = false;
  String _userMessage = "";

  FileModel(this._can, this._configData);

  set saveByteFile(bool save) {
    _saveByteFile = save;
    notifyListeners();
  }

  bool get saveByteFile {
    return _saveByteFile;
  }

  void recordButtonEvent(void Function() onComplete) {
    switch (_can.recordState) {
      case (RecordState.fileReady):
        _can.recordState = RecordState.inProgress;
        break;

      case (RecordState.inProgress):
        _can.recordState = RecordState.disabled;
        parseDataFile(false, onComplete);
        break;

      default:
        break;
    }
  }

  RecordState get recordState {
    return _can.recordState;
  }

  Future<void> openConfigFile(void Function(bool success) onComplete) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(openConfigFileIsolate, receivePort.sendPort);
    _userMessage = "";

    receivePort.listen((message) {
      try {
        final configMap = loadYaml(message) as Map;
        _configData.updateFromNewConfig(ConfigData.fromMap(configMap));
        onComplete(true);
      } on Exception catch (e, _) {
        _userMessage = e.toString();
        onComplete(false);
      }
      receivePort.close();
    });
  }

  void saveConfigFile() {
    if (_configData.telemetry.isNotEmpty) {
      saveFile(generateConfigFile(_configData));
    }
  }

  void saveHeaderFile() {
    saveFile(generateHeaderFile(_configData));
  }

  Future<void> createDataFile() async {
    // create the file here, pass to the comm isolate, and save data there
    final receivePort = ReceivePort();
    receivePort.listen((message) {
      if (message is String) {
        if (message.isNotEmpty) {
          _can.dataFile = message;
          _can.recordState = RecordState.fileReady;
        } else {
          _can.recordState = RecordState.disabled;
        }
        notifyListeners();
      }
      receivePort.close();
    });
    await Isolate.spawn(createDataFileIsolate, receivePort.sendPort);
  }

  Future<void> parseDataFile(
      bool fileSelection, void Function() onComplete) async {
    final completer = Completer<SendPort>();
    final receivePort = ReceivePort();
    _userMessage = "";

    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else {
        if (message is String && message.isNotEmpty) {
          _userMessage = message;
        } else {
          _userMessage = Message.info.parseData;
        }
        onComplete();
        receivePort.close();
      }
    });
    await Isolate.spawn(parseDataFileIsolate, receivePort.sendPort);
    SendPort sendPort = await completer.future;
    sendPort.send(fileSelection ? "" : _can.dataFile);
    sendPort.send(saveByteFile);
    sendPort.send(_configData.toMap());
  }

  String get userMessage {
    return _userMessage;
  }

}
