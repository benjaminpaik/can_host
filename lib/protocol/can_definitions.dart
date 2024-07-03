
const validBaudRates = [
  1000000,
  800000,
  500000,
  250000,
  125000,
  100000,
  95000,
  83000,
  50000,
  47000,
  33000,
  20000,
  10000,
  5000,
];

enum RequestPriorities {
  priority1(0),
  priority2(1),
  priority3(2),
  priority4(3),
  signalError(14),
  notAvailable(15);

  final int value;
  const RequestPriorities(this.value);
}

enum CanMessageTypes {
  standard(0x00),
  rtr(0x01),
  extended(0x02),
  fd(0x04),
  brs(0x08),
  esi(0x10),
  echo(0x20),
  errorFrame(0x40),
  status(0x80);

  final int value;
  const CanMessageTypes(this.value);
}

enum CanTxIndices {
  // base indices
  type(0),
  canId(1),
  data(2);

  final int value;
  const CanTxIndices(this.value);

  // common indices
  static int get mode => data.value;
  static int get sequence => data.value + 1;
  // command indices
  static int get command0 => data.value + 2;
  static int get command1 => data.value + 3;
  static int get command2 => data.value + 4;
  static int get command3 => data.value + 5;
  // telemetry request indices
  static int get stateIndex => data.value + 2;
  static int get enable => data.value + 3;
  // parameter read/write indices
  static int get parameterIndex0 => data.value + 2;
  static int get parameterIndex1 => data.value + 3;
  static int get parameterValue0 => data.value + 4;
  static int get parameterValue1 => data.value + 5;
  static int get parameterValue2 => data.value + 6;
  static int get parameterValue3 => data.value + 7;
}

enum CanRxIndices {
  canId(0),
  data(1);

  final int value;
  const CanRxIndices(this.value);

  // common indices
  static int get mode => data.value;
  // telemetry response indices
  static int get timestamp0 => data.value + 1;
  static int get timestamp1 => data.value + 2;
  static int get stateIndex => data.value + 3;
  static int get stateValue0 => data.value + 4;
  static int get stateValue1 => data.value + 5;
  static int get stateValue2 => data.value + 6;
  static int get stateValue3 => data.value + 7;
  // parameter read/write indices
  static int get parameterIndex0 => data.value + 1;
  static int get parameterIndex1 => data.value + 2;
  static int get parameterValue0 => data.value + 3;
  static int get parameterValue1 => data.value + 4;
  static int get parameterValue2 => data.value + 5;
  static int get parameterValue3 => data.value + 6;
}

class CanModes {
  static const int nullMode = 0;
  static const int idleMode = 1;
  static const int runMode = 2;
  static const int telemetrySelectMode = 250;
  static const int parameterLengthMode = 251;
  static const int parameterReadMode = 252;
  static const int parameterWriteMode = 253;
  static const int parameterFlashMode = 254;
  static const int bootloaderMode = 255;
}

class CanInfo {
  static const defaultPeriod = 10;
  static const maxPeriod = 60000;
  static const defaultBaudRate = 500000;
  static const dataPacketMax = 8;
  static const dataPacketMin = 0;
  static const txPacketMax = dataPacketMax + 2;
  static const rxPacketMax = dataPacketMax + 1;
  static const standardIdMax = 0x7FF;
  static const standardIdMin = 0;
  static const extendedIdMax = 0x1FFFFFFF;
  static const extendedIdMin = 0;

  final minTxLength = CanTxIndices.mode + 1;
  final minRxLength = CanRxIndices.mode + 1;
  final commandTxLength = CanTxIndices.command3 + 1;
  final telemetryTxLength = CanTxIndices.enable + 1;
  final telemetryRxLength = CanRxIndices.stateValue3 + 1;
  final parameterTxLength = CanTxIndices.parameterValue3 + 1;
  final parameterRxLength = CanRxIndices.parameterValue3 + 1;

  static const timestampRollover = 0xFFFF;
  static const timestampHostThreshold = timestampRollover - 100;
}
