import 'dart:async';
import 'package:can_host/misc/config_data.dart';
import 'package:flutter/material.dart';
import 'package:can_host/misc/telemetry.dart';
import 'package:can_host/widgets/oscilloscope_widget.dart';

import '../protocol/can_definitions.dart';
import '../protocol/can_protocol.dart';

const _textUpdateIntervalMs = 250;
const _plotUpdateIntervalMs = 50;
const _plotTimeSpan = 5.0;
const _maxDataPoints = (_plotTimeSpan * 1000 / _plotUpdateIntervalMs);

class TelemetryModel extends ChangeNotifier {
  int _startTime = 0,
      _graphUpdateCount = 0,
      _textUpdateCount = 0,
      _statusPrevious = -1;

  final CANApi _can;
  final ConfigData _configData;
  final _plotData = PlotData([], ySegments: 8, backgroundColor: Colors.black);

  TelemetryModel(this._can, this._configData) {
    // initialize the start time and start the timer
    _startTime = DateTime.now().millisecondsSinceEpoch;
    Timer.periodic(
        const Duration(milliseconds: _plotUpdateIntervalMs), _timerCallback);
  }

  void startPlots() {
    _startTime = DateTime.now().millisecondsSinceEpoch;
    _plotData.resetSamples();
  }

  void _timerCallback(Timer t) {
    if (_can.isRunning && _can.rx.mode < CanModes.telemetrySelectMode) {
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final elapsedTime = (currentTime - _startTime).toDouble() / 1000.0;

      int i = 0;
      for (int canIndex in _can.tx.enabledStates) {
        _configData.telemetry[i].setBitValue(_can.rx.stateValues[canIndex]);
        _plotData.curves[i].value = _configData.telemetry[i].value;
        _plotData.curves[i]
            .updateTimeScaling(_maxDataPoints.toInt(), _plotTimeSpan);
        i++;
      }

      _plotData.updateSamples(elapsedTime);
      if ((_graphUpdateCount++) %
              (_textUpdateIntervalMs / _plotUpdateIntervalMs) ==
          0) {
        ++_textUpdateCount;
      }
      // detectCanChannels();
      notifyListeners();
    }
  }

  void updatePlotDataFromConfig() {
    final telemetry = _configData.telemetry;
    _plotData.curves = List.generate(
        telemetry.length,
        (i) => PlotCurve(telemetry[i].name, telemetry[i].max, telemetry[i].min,
            color: telemetry[i].color)
          ..displayed = telemetry[i].display);
    // set the selected oscilloscope state to the first state displayed
    _plotData.selectedState = _plotData.curves
        .firstWhere((element) => element.displayed,
            orElse: () => _plotData.curves.first)
        .name;
    _loadTelemetryTable();
  }

  void _loadTelemetryTable() {
    ++_textUpdateCount;
    notifyListeners();
  }

  set selectedState(String name) {
    _plotData.selectedState = name;
  }

  PlotData get plotData {
    return _plotData;
  }

  List<String> get modes {
    return _configData.modes;
  }

  List<Telemetry> get telemetry {
    return _configData.telemetry;
  }

  BitStatus get statusBits {
    return _configData.status;
  }

  int get graphUpdateCount {
    return _graphUpdateCount;
  }

  int get textUpdateCount {
    return _textUpdateCount;
  }

  set statusState(String? state) {
    if (state != null) {
      for (int i = 0; i < _configData.telemetry.length; i++) {
        if (state == _configData.telemetry[i].name) {
          _configData.status.stateName = state;
          _configData.status.stateIndex = i;
        }
      }
      notifyListeners();
    }
  }

  String get statusState {
    return _configData.status.stateName;
  }

  bool get statusChanged {
    bool changed = false;
    if (_configData.telemetry.isNotEmpty) {
      final status =
          _configData.telemetry[_configData.status.stateIndex].value.toInt();
      changed = (status != _statusPrevious);
      _configData.status.value = status;
      _statusPrevious = status;
    }
    return changed;
  }

  void updateDisplaySelection() {
    for (int i = 0; i < _configData.telemetry.length; i++) {
      _plotData.curves[i].displayed = _configData.telemetry[i].display;
    }
    notifyListeners();
  }
}
