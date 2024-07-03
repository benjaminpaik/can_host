import 'dart:io' show Directory, Platform;

import 'dart:ffi';
import 'package:ffi/ffi.dart' show malloc;
import 'package:can_host/protocol/can_definitions.dart';

class CanInterface {
  static final CanInterface _instance = CanInterface._internal();
  late final DynamicLibrary nativeLib;
  final Pointer<Uint8> _txData = malloc<Uint8>(8);
  final Pointer<Uint8> _rxData = malloc<Uint8>(8);
  final Pointer<Uint32> _rxCanId = malloc<Uint32>(1);
  final Pointer<Uint8> _rxLength = malloc<Uint8>(1);

  factory CanInterface() {
    return _instance;
  }

  CanInterface._internal() {
    nativeLib = _loadLibrary();
  }

  // FFI function mapping
  late final int Function() _getNumCanChannels = nativeLib
      .lookup<NativeFunction<Int32 Function()>>("getNumCanChannels")
      .asFunction();
  // API method
  int numChannels() {
    return _getNumCanChannels();
  }

  // FFI function mapping
  late final Pointer<Uint8> Function() _getCanChannels = nativeLib
      .lookup<NativeFunction<Pointer<Uint8> Function()>>("getCanChannels")
      .asFunction();
  // API method
  List<int> getChannels() {
    final numChannels = _getNumCanChannels();
    if (numChannels > 0) {
      final canChannels = _getCanChannels();
      return List<int>.generate(numChannels, (index) => canChannels[index]);
    } else {
      return List<int>.empty();
    }
  }

  // FFI function mapping
  late final void Function(int channel, bool enable) _canIdentify = nativeLib
      .lookup<NativeFunction<Void Function(Uint8, Bool)>>("canIdentify")
      .asFunction();
  // API method
  void identifyChannel(int channel, bool enable) {
    _canIdentify(channel, enable);
  }

  // FFI function mapping
  late final bool Function(int channel, int baudRate) _canInitialize = nativeLib
      .lookup<NativeFunction<Bool Function(Uint8 channel, Int32 baudRate)>>(
          "canInitialize")
      .asFunction();
  // API method
  bool initChannel(int channel, int baudRate) {
    return _canInitialize(channel, baudRate);
  }

  // FFI function mapping
  late final void Function(int channel) _canDeInitialize = nativeLib
      .lookup<NativeFunction<Void Function(Uint8 channel)>>("canDeInitialize")
      .asFunction();
  // API method
  void deInitChannel(int channel) {
    _canDeInitialize(channel);
  }

  // FFI function mapping
  late final bool Function(
          int channel, int type, int canId, Pointer<Uint8> data, int length)
      _canWrite = nativeLib
          .lookup<
              NativeFunction<
                  Bool Function(Uint8 channel, Uint8 type, Uint32 canId,
                      Pointer<Uint8> data, Uint8 length)>>("canWrite")
          .asFunction();
  // API method
  bool write(int channel, int type, int canId, List<int> data) {
    int length = (data.length > CanInfo.dataPacketMax)
        ? CanInfo.dataPacketMax
        : data.length;
    for (int i = 0; i < length; i++) {
      _txData[i] = data[i];
    }
    return _canWrite(channel, type, canId, _txData, length);
  }

  // FFI function mapping
  late final bool Function(int channel, Pointer<Uint32> canId,
          Pointer<Uint8> data, Pointer<Uint8> length) _canRead =
      nativeLib
          .lookup<
              NativeFunction<
                  Bool Function(Uint8 channel, Pointer<Uint32> canId,
                      Pointer<Uint8> data, Pointer<Uint8> length)>>("canRead")
          .asFunction();
  // API method
  (bool, int, List<int>) read(int channel) {
    final success = _canRead(channel, _rxCanId, _rxData, _rxLength);
    final rxData = List<int>.generate(
        _rxLength.value, (index) => (_rxData + index).value);
    return (success, _rxCanId.value, rxData);
  }
}

DynamicLibrary _loadLibrary() {
  String path = "";
  if (Platform.isWindows) {
    path = '${Directory.current.path}\\canlib\\dartpeakcanffi.dll';
  } else if (Platform.isMacOS) {
    path = '${Directory.current.path}/canlib/dartpeakcanffi.dylib';
  } else if (Platform.isLinux) {
    path = '${Directory.current.path}/canlib/dartpeakcanffi.so';
  } else {
    throw 'PEAK CAN dynamic library not found';
  }
  return DynamicLibrary.open(path);
}
