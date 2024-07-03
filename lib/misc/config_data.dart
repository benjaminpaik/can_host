import 'dart:typed_data';

import 'package:can_host/misc/parameter.dart';
import 'package:can_host/misc/telemetry.dart';

import '../protocol/can_definitions.dart';

enum ConfigKeys {
  can,
  command,
  telemetry,
  status,
  parameters,
}

enum ConfigCanKeys {
  baud,
  period,
  hostId,
  deviceId,
  stateSelect,
}

enum ConfigCommandKeys {
  max,
  min,
  modes,
}

enum ConfigParameterKeys {
  name,
  type,
  value,
}

class ConfigData {
  int _baudRate = CanInfo.defaultBaudRate,
      _commPeriod = CanInfo.defaultPeriod,
      _hostId = 0,
      _deviceId = 0,
      _commandMax = 1000,
      _commandMin = -1000;
  var stateSelect = <int>{};
  List<String> modes = List.empty(growable: true);
  List<Telemetry> telemetry = List.empty(growable: true);
  BitStatus status = BitStatus();
  List<Parameter> parameter = List.empty(growable: true);

  set baudRate(int value) {
    if (validBaudRates.contains(value)) {
      _baudRate = value;
    } else {
      throw FormatException;
    }
  }

  int get baudRate {
    return _baudRate;
  }

  set commPeriod(int value) {
    if (value >= CanInfo.defaultPeriod) {
      _commPeriod = value;
    } else {
      throw FormatException;
    }
  }

  int get commPeriod {
    return _commPeriod;
  }

  set deviceId(int id) {
    if (id > CanInfo.standardIdMax || id < CanInfo.standardIdMin) {
      throw Exception();
    } else {
      _deviceId = id;
    }
  }

  int get deviceId {
    return _deviceId;
  }

  set hostId(int id) {
    if (id > CanInfo.standardIdMax || id < CanInfo.standardIdMin) {
      throw Exception();
    } else {
      _hostId = id;
    }
  }

  int get hostId {
    return _hostId;
  }

  void setRange(int max, int min) {
    if (max > min) {
      _commandMax = max;
      _commandMin = min;
    } else {
      throw FormatException;
    }
  }

  int get commandMax {
    return _commandMax;
  }

  int get commandMin {
    return _commandMin;
  }

  void updateFromNewConfig(ConfigData newConfig) {
    _baudRate = newConfig.baudRate;
    _commPeriod = newConfig._commPeriod;
    _hostId = newConfig._hostId;
    _deviceId = newConfig._deviceId;
    stateSelect = newConfig.stateSelect;
    _commandMax = newConfig.commandMax;
    _commandMin = newConfig.commandMin;
    modes = newConfig.modes;
    telemetry = newConfig.telemetry;
    status = newConfig.status;

    final oldParameters = parameter;
    parameter = newConfig.parameter;

    if (parameter.isNotEmpty && (parameter.length == oldParameters.length)) {
      for (int i = 0; i < parameter.length; i++) {
        parameter[i].deviceValue = oldParameters[i].deviceValue;
        parameter[i].connectedValue = oldParameters[i].connectedValue;
      }
    }
  }

  Map toMap() {
    final canMap = {
      ConfigCanKeys.baud.name: baudRate,
      ConfigCanKeys.period.name: _commPeriod,
      ConfigCanKeys.hostId.name: _hostId,
      ConfigCanKeys.deviceId.name: _deviceId,
      ConfigCanKeys.stateSelect.name: stateSelect,
    };

    final commandMap = {
      ConfigCommandKeys.max.name: commandMax,
      ConfigCommandKeys.min.name: commandMin,
      ConfigCommandKeys.modes.name: modes,
    };

    final telemetryList = telemetry.map((e) {
      return {
        TelemetryKeys.name.name: e.name,
        TelemetryKeys.max.name: e.max,
        TelemetryKeys.min.name: e.min,
        TelemetryKeys.type.name: e.type.name,
        TelemetryKeys.scale.name: e.scale,
        TelemetryKeys.color.name: e.color,
        TelemetryKeys.display.name: e.display.toString(),
      };
    });

    return {
      ConfigKeys.can.name: canMap,
      ConfigKeys.command.name: commandMap,
      ConfigKeys.telemetry.name: telemetryList,
      ConfigKeys.status.name: status.toMap(),
    };
  }

  static ConfigData fromMap(Map configMap) {
    final configData = ConfigData();

    // parse CAN settings
    var canMap = configMap[ConfigKeys.can.name];
    try {
      canMap = canMap as Map;
    } catch (e) {
      throw const FormatException("invalid CAN settings");
    }

    try {
      final baudRate = canMap[ConfigCanKeys.baud.name] as int;
      if (validBaudRates.contains(baudRate)) {
        configData.baudRate = baudRate;
      } else {
        throw Exception();
      }
    } catch (e) {
      throw const FormatException("invalid CAN baudrate");
    }

    try {
      final period = canMap[ConfigCanKeys.period.name] as int;
      if (period > 0 && period <= CanInfo.maxPeriod) {
        configData.commPeriod = period;
      } else {
        throw Exception();
      }
    } catch (e) {
      throw const FormatException("invalid CAN period");
    }

    try {
      final hostId = canMap[ConfigCanKeys.hostId.name] as int;
      if (hostId > 0 && hostId <= CanInfo.extendedIdMax) {
        configData.hostId = hostId;
      } else {
        throw Exception();
      }
    } catch (e) {
      throw const FormatException("invalid CAN host ID");
    }

    try {
      final deviceId = canMap[ConfigCanKeys.deviceId.name] as int;
      if (deviceId > 0 && deviceId <= CanInfo.extendedIdMax) {
        configData.deviceId = deviceId;
      } else {
        throw Exception();
      }
    } catch (e) {
      throw const FormatException("invalid CAN device ID");
    }

    try {
      configData.stateSelect =
          Set<int>.from(canMap[ConfigCanKeys.stateSelect.name]);
    } catch (e) {
      throw const FormatException("invalid CAN state select");
    }

    // parse command settings
    var commandMap = configMap[ConfigKeys.command.name];
    try {
      commandMap = commandMap as Map;
    } catch (e) {
      throw const FormatException("invalid command settings");
    }

    try {
      final commandMax = commandMap[ConfigCommandKeys.max.name] as int;
      final commandMin = commandMap[ConfigCommandKeys.min.name] as int;
      configData.setRange(commandMax, commandMin);
    } catch (e) {
      throw const FormatException("invalid command range");
    }

    try {
      configData.modes =
          List<String>.from(commandMap[ConfigCommandKeys.modes.name]);
    } catch (e) {
      throw const FormatException("invalid command buttons");
    }

    // parse telemetry settings
    final telemetryStringEnumMap = Map<String, TelemetryKeys>.fromEntries(
        TelemetryKeys.values.map((e) => MapEntry(e.name, e)));
    var telemetryList = <Map>[];
    try {
      telemetryList = List<Map>.from(configMap[ConfigKeys.telemetry.name]);
    } catch (e) {
      throw const FormatException("invalid telemetry settings");
    }

    for (int i = 0; i < telemetryList.length; i++) {
      try {
        var telemetryMap = telemetryList[i]
            .map((k, v) => MapEntry(telemetryStringEnumMap[k]!, v));
        final colorString = telemetryMap[TelemetryKeys.color];
        final typeString = telemetryMap[TelemetryKeys.type];
        // convert string values to different types
        telemetryMap[TelemetryKeys.color] = colorMap[colorString];
        telemetryMap[TelemetryKeys.type] =
            (typeString == TelemetryType.float.name)
                ? TelemetryType.float
                : TelemetryType.int;
        configData.telemetry.add(Telemetry.fromMap(telemetryMap));
      } catch (e) {
        throw FormatException("invalid telemetry at index $i");
      }
    }

    // parse status settings
    var statusMap = <String, dynamic>{};
    try {
      statusMap = Map<String, dynamic>.from(configMap[ConfigKeys.status.name]);
    } catch (e) {
      throw const FormatException("invalid status settings");
    }
    configData.status = BitStatus.fromMap(statusMap);

    // parse parameter settings
    var parameterList = <Map>[];
    try {
      parameterList = List<Map>.from(configMap[ConfigKeys.parameters.name]);
    } catch (e) {
      throw const FormatException("invalid parameter settings");
    }

    var parameterError = "";
    for (int i = 0; i < parameterList.length; i++) {
      try {
        final parameter = Parameter();
        final parameterMap = parameterList[i];

        parameter.name = parameterMap[ConfigParameterKeys.name.name];
        parameter.type = (parameterMap[ConfigParameterKeys.type.name] ==
                ParameterType.float.name)
            ? ParameterType.float
            : ParameterType.int;

        final parameterValue = parameterMap[ConfigParameterKeys.value.name];

        final byteData = ByteData(4);
        if (parameter.type == ParameterType.float &&
            parameterValue.runtimeType == double) {
          byteData.setFloat32(0, parameterValue);
        } else if (parameter.type == ParameterType.int &&
            parameterValue.runtimeType == int) {
          byteData.setInt32(0, parameterValue);
        } else {
          parameterError = " - type mismatch";
          throw const FormatException();
        }
        parameter.currentValue = byteData.getInt32(0);
        parameter.fileValue = parameter.currentValue;
        configData.parameter.add(parameter);
      } catch (e) {
        throw FormatException("invalid parameter at index $i$parameterError");
      }
    }
    return configData;
  }
}
