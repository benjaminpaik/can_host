import 'package:flutter/material.dart';
import 'dart:async';
import 'package:can_host/definitions.dart';
import 'package:can_host/protocol/can_definitions.dart';
import 'package:can_host/protocol/can_protocol.dart';

import '../misc/config_data.dart';
import '../misc/parameter.dart';

class CanModel extends ChangeNotifier {

  String _userMessage = "";
  final CANApi _can;
  final ConfigData _configData;
  int? _channelSelection;
  int _command = 0;

  CanModel(this._can, this._configData);

  Future<void> canConnect() async {
    if (!_can.isRunning) {
      if (_channelSelection != null) {
        await _can.openPort(_channelSelection!, _configData.baudRate, _configData.commPeriod);
        _can.tx.id = _configData.hostId;
        _can.tx.type = CanMessageTypes.standard;
        _can.sendPacket();
        _userMessage = Message.info.connected;
      }
    } else {
      _can.closePort();
      _userMessage = Message.info.disconnected;
    }
  }

  // TODO: may need to modify this to refresh UI
  int get numChannels {
    return _can.numChannels;
  }

  List<String> get canChannels {
    return _can.channels;
  }

  String? get channelSelection {
    if(_channelSelection != null) {
      return _channelSelection.toString();
    }
    else {
      return null;
    }
  }

  set channelSelection(String? selection) {
    final channel = int.tryParse(selection ?? "");
    if(channel != null) {
      _channelSelection = channel;
      notifyListeners();
    }
  }

  int get baudRate {
    return _configData.baudRate;
  }

  set baudRate(int value) {
    _configData.baudRate = value;
    notifyListeners();
  }

  bool get isRunning {
    return _can.isRunning;
  }

  int get command {
    return _command;
  }

  set command(int value) {
    _command = value;
    _can.tx.setCommand(mode, _command);
    _can.sendPacket();
    notifyListeners();
  }

  int get commandMax {
    return _configData.commandMax;
  }

  int get commandMin {
    return _configData.commandMin;
  }

  int get mode {
    return _can.rx.mode;
  }

  set mode(int value) {
    _can.tx.setCommand(mode, _command);
    _can.sendPacket();
  }

  int get hostId {
    return _configData.hostId;
  }

  int get deviceId {
    return _configData.deviceId;
  }

  bool setDeviceId(int? id) {
    _userMessage = "";
    if (id != null) {
      try {
        _configData.deviceId = id;
        notifyListeners();
        return true;
      } catch (e) {
        _userMessage = Message.error.deviceIdRange;
      }
    } else {
      _userMessage = Message.error.deviceIdText;
    }
    return false;
  }

  set commPeriod(int value) {
    if (value > 0) {
      _configData.commPeriod = value;
      _can.txPeriod = _configData.commPeriod;
      notifyListeners();
    }
  }

  int get commPeriod {
    return _configData.commPeriod;
  }

  void updateFromConfig() {
    notifyListeners();
  }

  Future<bool> getParametersUserSequence() async {
    _userMessage = "";
    bool success = false;
    await getNumParameters().then((numDeviceParameters) async {
      if (numDeviceParameters >= 0) {
        if (_configData.parameter.isNotEmpty &&
            numDeviceParameters != _configData.parameter.length) {
          _userMessage = Message.error.parameterLengthMatch;
        } else {
          if (_configData.parameter.isEmpty) {
            for (int i = 0; i < numDeviceParameters; i++) {
              _configData.parameter.add(Parameter());
            }
          }

          await getParameters().then((getParameterSuccess) {
            if (getParameterSuccess) {
              for (var parameter in _configData.parameter) {
                parameter.currentValue = parameter.deviceValue;
              }
              _userMessage = Message.info.parameterGet;
              success = true;
            } else {
              _userMessage = Message.error.parameterGet;
            }
          });
        }
      } else {
        _userMessage = Message.error.parameterNum;
      }
    });
    return success;
  }

  Future<int> getNumParameters() async {
    int deviceParameterLength = -1;
    if (_can.isRunning) {

      _can.tx.parameterLengthMode();
      _can.sendPacket();
      _can.startWatchdog(parameterTimeout);

      while (!_can.watchdogTripped) {
        if (_can.rx.mode == CanModes.parameterLengthMode) {
          deviceParameterLength = _can.rx.parameterLength;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 1));
      }
      _can.tx.mode = CanModes.nullMode;
      _can.sendPacket();
    }
    return deviceParameterLength;
  }

  Future<bool> getParameters() async {
    if (_can.isRunning) {
      final parameters = _configData.parameter;

      for (int index = 0; index < _can.rx.parameterLength; index++) {

        _can.tx.parameterReadMode(index);
        _can.sendPacket();
        _can.startWatchdog(parameterTimeout);

        while (!_can.watchdogTripped) {
          if ((_can.rx.mode == CanModes.parameterReadMode &&
              _can.rx.parameterIndex == index)) {
            parameters[index].deviceValue = _can.rx.parameterValue;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 1));
        }
        if(_can.watchdogTripped) return false;
      }
      _can.tx.mode = CanModes.nullMode;
      _can.sendPacket();
    }
    return true;
  }

  Future<bool> sendParameters() async {
    bool success = false;
    _userMessage = Message.error.parameterWrite;
    final parameters = _configData.parameter;

    if (_can.isRunning) {
      for (int index = 0; index < _can.rx.parameterLength; index++) {

        _can.tx.parameterWriteMode(index, parameters[index].currentValue?.toInt() ?? 0);
        _can.sendPacket();
        _can.startWatchdog(parameterTimeout);

        while (!_can.watchdogTripped) {
          if ((_can.rx.mode == CanModes.parameterWriteMode) &&
              (_can.rx.parameterIndex == index)) break;
          await Future.delayed(const Duration(milliseconds: 1));
        }
        if(_can.watchdogTripped) return false;
      }

      await getParameters().then((parametersRetrieved) {
        if (parametersRetrieved) {
          final parameterMismatch = parameters.where((e) => e.deviceValue != e.currentValue).map((e) => e.name);
          if (parameterMismatch.isEmpty) {
            _userMessage = Message.info.parameterWrite;
            success = true;
          } else {
            _userMessage = Message.error.parameterUpdate(parameterMismatch);
          }
        }
      });
    }
    return success;
  }

  Future<bool> flashParameters() async {
    _userMessage = "";
    bool success = false, nullComplete = false;
    if (_can.isRunning) {
      _can.tx.mode = CanModes.nullMode;
      _can.sendPacket();
      _can.startWatchdog(parameterTimeout);

      while (!_can.watchdogTripped) {
        if (_can.rx.mode == CanModes.nullMode) {
          nullComplete = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 1));
      }

      if (nullComplete) {

        _can.tx.parameterFlashMode();
        _can.sendPacket();
        _can.startWatchdog(parameterTimeout);

        while (!_can.watchdogTripped) {
          if (_can.rx.mode == CanModes.parameterFlashMode) {
            _userMessage = Message.info.parameterFlash;
            success = true;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      if (!nullComplete || !success) {
        _userMessage = Message.error.parameterFlash;
      }
      _can.tx.mode = CanModes.nullMode;
      _can.sendPacket();
    }
    return success;
  }

  Future<bool> initBootloader() async {
    _userMessage = "";
    bool success = false, nullComplete = false;
    if (_can.isRunning) {
      _can.tx.mode = CanModes.nullMode;
      _can.sendPacket();
      _can.startWatchdog(parameterTimeout);

      while (!_can.watchdogTripped) {
        if (_can.rx.mode == CanModes.nullMode) {
          nullComplete = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 1));
      }

      if (nullComplete) {
        _can.tx.mode = CanModes.bootloaderMode;
        _can.sendPacket();
        _can.startWatchdog(parameterTimeout);

        while (!_can.watchdogTripped) {
          if (_can.rx.mode == CanModes.bootloaderMode) {
            _userMessage = Message.info.bootloader;
            success = true;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      if (!nullComplete || !success) {
        _userMessage = Message.error.bootloader;
      }
    }
    return success;
  }

  String get userMessage {
    return _userMessage;
  }

}
