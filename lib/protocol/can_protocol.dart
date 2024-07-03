import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:can_host/misc/file_utilities.dart';
import 'package:can_host/protocol/peak_can_interface.dart';
import 'can_definitions.dart';

enum CANCommKeys {
  channel,
  baudRate,
  commPeriod,
  running,
  dataFile,
  recordState,
}

const _initConfigData = {
  CANCommKeys.channel: 0,
  CANCommKeys.baudRate: CanInfo.defaultBaudRate,
  CANCommKeys.commPeriod: CanInfo.defaultPeriod,
  CANCommKeys.running: false,
  CANCommKeys.dataFile: "",
  CANCommKeys.recordState: RecordState.disabled,
};

class CanTx {
  final _enabledStates = <int>{};
  final data = List<int>.generate(CanInfo.dataPacketMax, (index) => 0);

  set type(CanMessageTypes type) {
    data[CanTxIndices.type.value] = type.value;
  }

  set id(int id) {
    data[CanTxIndices.canId.value] = id;
  }

  set mode(int mode) {
    data[CanTxIndices.mode] = mode;
  }

  void setCommand(int mode, int value) {
    if (mode >= 0 && mode < CanModes.telemetrySelectMode) {
      final byteData = ByteData(4);
      byteData.setInt32(0, value);
      data[CanTxIndices.command0] = byteData.getUint8(0);
      data[CanTxIndices.command1] = byteData.getUint8(1);
      data[CanTxIndices.command2] = byteData.getUint8(2);
      data[CanTxIndices.command3] = byteData.getUint8(3);
    }
    // TODO: test bit-shifting
  }

  void telemetrySelectMode(int index, bool enable) {
    data[CanTxIndices.mode] = CanModes.telemetrySelectMode;
    data[CanTxIndices.stateIndex] = index;

    if(enable) {
      data[CanTxIndices.enable] = 1;
      _enabledStates.add(index);
    }
    else {
      data[CanTxIndices.enable] = 0;
      _enabledStates.remove(index);
    }
  }

  Set<int> get enabledStates {
    return _enabledStates;
  }

  void parameterLengthMode() {
    data[CanTxIndices.mode] = CanModes.parameterLengthMode;
  }

  void parameterReadMode(int index) {
    data[CanTxIndices.mode] = CanModes.parameterReadMode;
    data[CanTxIndices.parameterIndex0] = (index >> 8) & 0xFF;
    data[CanTxIndices.parameterIndex1] = (index & 0xFF);
  }

  void parameterWriteMode(int index, int value) {
    data[CanTxIndices.mode] = CanModes.parameterWriteMode;
    data[CanTxIndices.parameterIndex0] = (index >> 8) & 0xFF;
    data[CanTxIndices.parameterIndex1] = (index & 0xFF);

    final byteData = ByteData(4);
    byteData.setInt32(0, value);
    data[CanTxIndices.parameterValue0] = byteData.getUint8(0);
    data[CanTxIndices.parameterValue1] = byteData.getUint8(1);
    data[CanTxIndices.parameterValue2] = byteData.getUint8(2);
    data[CanTxIndices.parameterValue3] = byteData.getUint8(3);
  }

  void parameterFlashMode() {
    data[CanTxIndices.mode] = CanModes.parameterFlashMode;
  }
}

class CanRx {
  final _stateValues = List.generate(256, (i) => 0, growable: false);
  final _parameters = <int, int>{};

  int _canId = 0;
  int _mode = 0;
  int _timestamp = 0;
  int _stateIndex = 0;
  int _parameterIndex = 0;
  int _parameterLength = 0;
  int _parameterValue = 0;

  void updateRxData(List<int> data) {

    // update the CAN ID and mode fields
    _canId = data[CanRxIndices.canId.value];
    if(data.length > CanRxIndices.mode) {
      _mode = data[CanRxIndices.mode];
    }

    // update variables depending on the mode
    switch (mode) {
      case (CanModes.parameterLengthMode):
        if (data.length > CanRxIndices.mode) {
          _parameterLength =
              ((data[CanRxIndices.parameterIndex0] & 0xFF) << 8) |
                  (data[CanRxIndices.parameterIndex1] & 0xFF);
        }
        break;

      case (CanModes.parameterReadMode):
        if (data.length > CanRxIndices.parameterValue3) {
          _parameterIndex = ((data[CanRxIndices.parameterIndex0] & 0xFF) << 8) |
              (data[CanRxIndices.parameterIndex1] & 0xFF);
          final byteData = ByteData(4);
          byteData.setUint8(0, data[CanRxIndices.parameterValue0]);
          byteData.setUint8(1, data[CanRxIndices.parameterValue1]);
          byteData.setUint8(2, data[CanRxIndices.parameterValue2]);
          byteData.setUint8(3, data[CanRxIndices.parameterValue3]);
          _parameterValue = byteData.getInt32(0);
          _parameters[_parameterIndex] = _parameterValue;
        }
        break;

      case (CanModes.parameterWriteMode):
        if(data.length > CanRxIndices.parameterIndex1) {
          _parameterIndex = ((data[CanRxIndices.parameterIndex0] & 0xFF) << 8) |
          (data[CanRxIndices.parameterIndex1] & 0xFF);
        }
        break;

      default:
        if(data.length > CanRxIndices.stateValue3) {
          _timestamp = ((data[CanRxIndices.timestamp0] & 0xFF) << 8) |
          (data[CanRxIndices.timestamp1] & 0xFF);
          _stateIndex = data[CanRxIndices.stateIndex] & 0xFF;
          final byteData = ByteData(4);
          byteData.setUint8(0, data[CanRxIndices.stateValue0]);
          byteData.setUint8(1, data[CanRxIndices.stateValue1]);
          byteData.setUint8(2, data[CanRxIndices.stateValue2]);
          byteData.setUint8(3, data[CanRxIndices.stateValue3]);
          _stateValues[_stateIndex] = byteData.getInt32(0);
        }
        break;
    }
  }

  int get canId {
    return _canId;
  }

  int get mode {
    return _mode;
  }

  int get parameterLength {
    return _parameterLength;
  }

  int get parameterIndex {
    return _parameterIndex;
  }

  int get parameterValue {
    return _parameterValue;
  }

  int get timestamp {
    return _timestamp;
  }

  int get stateIndex {
    return _stateIndex;
  }

  List<int> get stateValues {
    return _stateValues;
  }
}

class CANApi {
  final tx = CanTx();
  final rx = CanRx();

  Completer<SendPort> _sendPortCompleter = Completer<SendPort>();
  SendPort? _sendPort;
  final ReceivePort _receivePort;
  // clone initial config data
  final _configData = {..._initConfigData};
  var _watchdogTripped = false;
  bool get watchdogTripped => _watchdogTripped;

  CANApi() : _receivePort = ReceivePort() {
    _receivePort.listen(receiveDataEvent);
  }

  int get numChannels {
    return CanInterface().numChannels();
  }

  List<String> get channels {
    final canChannels = CanInterface().getChannels();
    return List<String>.generate(
        canChannels.length, (index) => canChannels[index].toString());
  }

  set dataFile(String file) {
    if (_sendPort != null) {
      _configData[CANCommKeys.dataFile] = file;
      _sendPort!.send({CANCommKeys.dataFile: file});
    }
  }

  String get dataFile {
    return _configData[CANCommKeys.dataFile] as String;
  }

  set recordState(RecordState state) {
    if (_sendPort != null) {
      _configData[CANCommKeys.recordState] = state;
      _sendPort!.send({CANCommKeys.recordState: state});
    }
  }

  RecordState get recordState {
    return _configData[CANCommKeys.recordState] as RecordState;
  }

  void receiveDataEvent(dynamic data) {
    if (data is List<int>) {
      if (data.isNotEmpty && data.length <= CanInfo.dataPacketMax) {
        rx.updateRxData(data);
      }
    } else if (data is SendPort) {
      _sendPortCompleter.complete(data);
    }
  }

  Future<void> openPort(int channel, int baudRate, int txPeriod) async {
    await Isolate.spawn(_commIsolate, _receivePort.sendPort);
    _sendPortCompleter = Completer<SendPort>();
    _sendPort = await _sendPortCompleter.future;

    if (_sendPort != null) {
      _configData[CANCommKeys.channel] = channel;
      _configData[CANCommKeys.baudRate] = baudRate;
      _configData[CANCommKeys.commPeriod] = txPeriod;
      _configData[CANCommKeys.running] = true;
      _sendPort!.send(_configData);
      sendPacket();
    }
  }

  set txPeriod(int period) {
    if (period > 0) {
      if (_sendPort != null) {
        _configData[CANCommKeys.commPeriod] = period;
        _sendPort!.send(_configData);
        sendPacket();
      }
    }
  }

  void closePort() {
    if (_sendPort != null) {
      _configData[CANCommKeys.running] = false;
      _sendPort!.send(_configData);
    }
  }

  void sendPacket() {
    if (_sendPort != null) {
      _sendPort!.send(tx.data);
    }
  }

  void startWatchdog(int timeout) {
    _watchdogTripped = false;
    Timer(Duration(milliseconds: timeout), () {
      _watchdogTripped = true;
    });
  }

  bool get isRunning {
    return _configData[CANCommKeys.running] as bool;
  }
}

class _CanProtocol {
  final canInterface = CanInterface();
  int _canChannel = 0;
  int _commPeriod = CanInfo.defaultPeriod;
  int _sequenceCounter = 0;
  final _txData = List<int>.filled(CanInfo.txPacketMax, 0);
  final _rxData = List<int>.filled(CanInfo.rxPacketMax, 0);

  void openChannel(int channel, int baudRate) async {
    final success = canInterface.initChannel(channel, baudRate);
    if (success) {
      canInterface.identifyChannel(channel, true);
      _canChannel = channel;
    }
  }

  void closePort() {
    canInterface.identifyChannel(_canChannel, false);
    canInterface.deInitChannel(_canChannel);
  }

  set commPeriod(int value) {
    if (value >= CanInfo.defaultPeriod) {
      _commPeriod = value;
    }
  }

  bool _rxProtocol() {
    final (success, canId, rxData) = canInterface.read(_canChannel);
    // load the CAN ID and payload into the same list
    if (success) {
      _rxData[CanRxIndices.canId.value] = canId;
      for (int i = 0; i < rxData.length; i++) {
        _rxData[CanRxIndices.data.value + i] = rxData[i];
      }
    }
    return success;
  }

  void _txProtocol() {
    _txData[CanTxIndices.sequence] = (_sequenceCounter++);
    // message type, CAN ID, and payload are all contained in the same list
    canInterface.write(
        _canChannel,
        _txData[CanTxIndices.type.value],
        _txData[CanTxIndices.canId.value],
        _txData.sublist(CanTxIndices.data.value));
  }

  void loadTxData(List<int> data) {
    for (int i = 0; i < _txData.length; i++) {
      _txData[i] = data[i];
    }
  }
}

Future<void> _commIsolate(SendPort sendPort) async {
  late Timer timer;
  IOSink? writer;
  _CanProtocol can = _CanProtocol();
  int startTime, previousTime = 0;
  final configData = {..._initConfigData};

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((data) {
    bool openClosePort = false;
    // TX bytes input
    if (data is List<int>) {
      can.loadTxData(data);
    } else if (data is Map) {
      // load all config data
      for (CANCommKeys key in data.keys) {
        if (configData.containsKey(key)) {
          // special actions for received maps
          switch (key) {
            case (CANCommKeys.running):
              openClosePort = (configData[key] != data[key]);
              break;

            case (CANCommKeys.recordState):
              if (data[key] == RecordState.inProgress) {
                final dataFile = configData[CANCommKeys.dataFile] as String;
                if (dataFile.isNotEmpty) {
                  writer = File(dataFile).openWrite();
                }
              } else {
                writer?.close();
              }
              break;

            default:
              break;
          }
          configData[key] = data[key];
        }
      }
      // update the TX rate
      can.commPeriod = configData[CANCommKeys.commPeriod] as int;
      // open and close COM port based on running key
      if (openClosePort) {
        if (configData[CANCommKeys.running] == true) {
          can.openChannel(
            configData[CANCommKeys.channel] as int,
            configData[CANCommKeys.baudRate] as int,
          );
        } else {
          timer.cancel();
          can.closePort();
          receivePort.close();
        }
      }
    }
  });

  while (configData[CANCommKeys.running] == false) {
    // yield to the listener
    await Future.delayed(Duration.zero);
  }

  timer = Timer.periodic(const Duration(microseconds: 500), (timer) {
    startTime = DateTime.now().millisecondsSinceEpoch;
    if (startTime - previousTime >= can._commPeriod) {
      can._txProtocol();
      previousTime = startTime;
    }
    if (can._rxProtocol()) {
      sendPort.send(can._rxData);
      if (configData[CANCommKeys.recordState] == RecordState.inProgress) {
        writer?.write(can._rxData.toString() + newline);
      }
    }
  });
}
