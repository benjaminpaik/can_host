import 'package:flutter/services.dart';
import 'package:can_host/misc/file_utilities.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:can_host/models/can_model.dart';

import '../models/file_model.dart';
import '../models/telemetry_model.dart';
import '../models/parameter_table_model.dart';
import '../protocol/can_definitions.dart';
import 'message_widget.dart';

const _verticalPadding = 8.0;
const _horizontalPadding = 8.0;

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final fileModel = Provider.of<FileModel>(context, listen: false);
    final telemetryModel = Provider.of<TelemetryModel>(context, listen: false);
    final parameterTableModel =
        Provider.of<ParameterTableModel>(context, listen: false);
    final canModel = Provider.of<CanModel>(context, listen: false);

    final openFileMenuItem = MenuItemButton(
        onPressed: () {
          fileModel.openConfigFile((bool success) {
            if (success) {
              canModel.updateFromConfig();
              telemetryModel.updatePlotDataFromConfig();
              parameterTableModel.initRows();
            }
            displayMessage(context, fileModel.userMessage);
          });
        },
        shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
        child: const Text("open file"));

    final saveFileMenuItem = MenuItemButton(
      onPressed: () {
        fileModel.saveConfigFile();
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyS, control: true),
      child: Selector<TelemetryModel, bool>(
        selector: (_, telemetryLoaded) => telemetryModel.telemetry.isNotEmpty,
        builder: (context, fileLoaded, child) {
          return Text(
            "save file",
            style: TextStyle(
              color: fileLoaded ? null : Colors.grey,
            ),
          );
        },
      ),
    );

    final createDataFileMenuItem = MenuItemButton(
      onPressed: () {
        if (canModel.isRunning) {
          fileModel.createDataFile();
        }
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyD, control: true),
      child: Selector<CanModel, bool>(
        selector: (_, model) => model.isRunning,
        builder: (context, running, child) {
          return Text(
            "create data file",
            style: TextStyle(
              color: running ? null : Colors.grey,
            ),
          );
        },
      ),
    );

    final parseDataMenuItem = MenuItemButton(
        child: const Text("parse data"),
        onPressed: () {
          fileModel.parseDataFile(
              true, () => displayMessage(context, fileModel.userMessage));
        });

    final saveByteFileMenuItem = MenuItemButton(
      child: Row(
        children: [
          const Text("save byte file"),
          Selector<TelemetryModel, bool>(
            selector: (_, selectorModel) => fileModel.saveByteFile,
            builder: (context, saveByteFile, child) {
              return Checkbox(
                  value: fileModel.saveByteFile,
                  onChanged: (bool? value) {
                    fileModel.saveByteFile = value ?? false;
                  });
            },
          ),
        ],
      ),
      onPressed: () {},
    );

    final createHeaderMenuItem = MenuItemButton(
      onPressed: () {
        fileModel.saveHeaderFile();
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyH, control: true),
      child: Selector<TelemetryModel, bool>(
        selector: (_, selectorModel) => selectorModel.telemetry.isNotEmpty,
        builder: (context, fileLoaded, child) {
          return Text(
            "create header",
            style: TextStyle(
              color: fileLoaded ? null : Colors.grey,
            ),
          );
        },
      ),
    );

    final programTargetMenuItem = MenuItemButton(
      onPressed: () {
        canModel.initBootloader().then((_) {
          displayMessage(context, canModel.userMessage);
          canModel.canConnect();
        });
      },
      shortcut: const SingleActivator(LogicalKeyboardKey.keyP, control: true),
      child: const Text("program target"),
    );

    final fileMenu = [
      openFileMenuItem,
      saveFileMenuItem,
      createDataFileMenuItem,
    ];

    final toolsMenu = [
      parseDataMenuItem,
      saveByteFileMenuItem,
      createHeaderMenuItem,
      programTargetMenuItem,
    ];

    final hostIdLabel = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 18.0),
      child: Selector<CanModel, int>(
        selector: (_, model) => model.hostId,
        builder: (context, recordState, child) {
          return Text("Host ID: ${canModel.hostId}");
        },
      ),
    );

    final deviceIdLabel = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 18.0),
      child: Selector<CanModel, int>(
        selector: (_, model) => model.deviceId,
        builder: (context, recordState, child) {
          return Text("Device ID: ${canModel.deviceId}");
        },
      ),
    );

    const canChannelLabel = Padding(
      padding: EdgeInsets.all(8.0),
      child: Text("Channel: "),
    );

    final recordButton = Selector<FileModel, RecordState>(
      selector: (_, selectorModel) => fileModel.recordState,
      builder: (context, recordState, child) {
        return IconButton(
            onPressed: () {
              fileModel.recordButtonEvent(() {
                displayMessage(context, fileModel.userMessage);
              });
            },
            icon: recordState.icon);
      },
    );

    final canChannelInput = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Selector<CanModel, String?>(
        selector: (_, model) => "${model.channelSelection}${model.numChannels}",
        builder: (context, _, child) {
          return DropdownButton(
            value: canModel.channelSelection,
            items: canModel.canChannels
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (String? comSelection) {
              canModel.channelSelection = comSelection;
            },
          );
        },
      ),
    );

    const baudRateLabel = Padding(
      padding: EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Text("Baud Rate: "),
    );

    final baudRateInput = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Selector<CanModel, int>(
        selector: (_, selectorModel) => selectorModel.baudRate,
        builder: (context, _, child) {
          return DropdownButton(
            value: canModel.baudRate,
            items: validBaudRates
                .map((item) =>
                    DropdownMenuItem(value: item, child: Text(item.toString())))
                .toList(),
            onChanged: (int? baudRate) {
              if (baudRate != null) {
                canModel.baudRate = baudRate;
              }
            },
          );
        },
      ),
    );

    const periodLabel = Padding(
      padding: EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Text("Tx Period: "),
    );

    final periodTextController =
        TextEditingController(text: canModel.commPeriod.toString());

    final periodInput = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: Selector<CanModel, int>(
        selector: (_, selectorModel) => selectorModel.commPeriod,
        builder: (context, commPeriod, child) {
          periodTextController.text = commPeriod.toString();
          return SizedBox(
            height: 35.0,
            width: 40.0,
            child: TextField(
              controller: periodTextController,
              onSubmitted: (text) {
                int? value = int.tryParse(text);
                if (value != null) {
                  canModel.commPeriod = value;
                  periodTextController.text = canModel.commPeriod.toString();
                }
              },
            ),
          );
        },
      ),
    );

    final connectButton = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _verticalPadding, horizontal: _horizontalPadding),
      child: SizedBox(
        width: 120.0,
        child: ElevatedButton(
          child: Selector<CanModel, bool>(
            selector: (_, model) => model.isRunning,
            builder: (context, isRunning, child) {
              return Text(isRunning ? "Disconnect" : "Connect");
            },
          ),
          onPressed: () {
            canModel.canConnect();
          },
        ),
      ),
    );

    // combine items from both menus and register shortcuts
    _initShortcuts(context, [...fileMenu, ...toolsMenu]);

    return Row(
      children: [
        MenuBar(children: [
          SubmenuButton(menuChildren: fileMenu, child: const Text('File')),
          SubmenuButton(menuChildren: toolsMenu, child: const Text('Tools')),
          recordButton,
        ]),
        const Spacer(),
        hostIdLabel,
        deviceIdLabel,
        canChannelLabel,
        canChannelInput,
        baudRateLabel,
        baudRateInput,
        periodLabel,
        periodInput,
        connectButton,
      ],
    );
  }
}

void _initShortcuts(BuildContext context, List<MenuItemButton> menuItems) {
  if (ShortcutRegistry.of(context).shortcuts.isEmpty) {
    final validMenuItems = menuItems
        .where((item) => item.shortcut != null && item.onPressed != null);
    final shortcutMap = {
      for (final item in validMenuItems)
        item.shortcut!: VoidCallbackIntent(item.onPressed!)
    };
    ShortcutRegistry.of(context).addAll(shortcutMap);
  }
}
