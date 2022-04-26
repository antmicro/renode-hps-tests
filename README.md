# HPS tests on Renode

Copyright (c) 2022 [Antmicro](https://www.antmicro.com/)

This repository contains a basic test setup for the STM32G0 part of HPS.
It verifies booting and flashing via I2C with the dedicated HPS Host Controller block.

## Obtaining Renode

You can download the latest Renode build from https://builds.renode.io - look for the linux-portable.tar.gz package.

Direct path to the latest release (recommended): https://dl.antmicro.com/projects/renode/builds/renode-latest.linux-portable.tar.gz.

Unpack it in a directory of your choice and add it to ``$PATH``.

You can run Renode with the ``./renode`` command, or run Robot tests with ``./renode-test``.

Renode documentation is available at https://docs.renode.io.

## Creating the platform

You can either load the provided script with ``include @hps.resc`` or follow the instructions below step by step.
If you want to use the script, skip to point 7.

> Note: You need to adjust the paths in the provided script to point to proper ELF files!


1. Create a machine:

```
mach create
```

2. Load a generic STM32G0 platform description:
(Note: start the path with ``@``)

```
machine LoadPlatformDescription @platforms/cpus/stm32g0.repl
```

3. Apply additional configuration to the platform, specific to HPS:

```
machine LoadPlatformDescriptionFromString "camera: I2C.DummyI2CSlave @ i2c2 0x24 { Register0Value: 0x01; Register1Value: 0xB0 }"
machine LoadPlatformDescriptionFromString "flashSpi: SPI.GigaDevice_GD25LQ @ spi1 { underlyingMemory: flash }"
machine LoadPlatformDescriptionFromString "cs: Miscellaneous.Button @ gpioPortA 8 { -> gpioPortA@8 }"
machine LoadPlatformDescriptionFromString "fpgaProgram_led: Miscellaneous.LED @ gpioPortC 15"
machine LoadPlatformDescriptionFromString "debug_led: Miscellaneous.LED @ gpioPortA 1"
machine LoadPlatformDescriptionFromString "gpioPortA: { 1 -> debug_led@0 }"
machine LoadPlatformDescriptionFromString "gpioPortB: { 0 -> flashSpi@0 }"
machine LoadPlatformDescriptionFromString "gpioPortC: { 15 -> fpgaProgram_led@0 }"
```

4. Load stage0 and stage1 binaries:

```
sysbus LoadELF @path-to-file/stage0
sysbus LoadELF @path-to-file/stage1_app
```

Alternatively, if you want to load stage1_app via I2C, you can just load the symbols - for easier debugging:

```
sysbus LoadELF @path-to-file/stage0
sysbus LoadSymbolsFrom @path-to-file/stage1_app
```

Loading symbols is optional.

5. Create the host controller in the emulation:

```
emulation AddHPSHostController
```

It creates the object ``host.HPSHostController`` that can be used to communicate with STM32G0 via I2C.

6. Create a connection between the controller and I2C1 on the STM32G0 board:

```
connector Connect sysbus.i2c1 host.HPSHostController
```

7. Start the simulation

```
start
```

You can pause at any moment with:

```
pause
```

These commands can be abbreviated as ``s`` and ``p`` respectively.

## Interacting with the HPS Host Controller

1. To display a list of available actions that the host controller can perform, type

```
host.HPSHostController
```

and hit Tab twice. You will see a list similar to:

```
 AttachTo
 DebugLog
 DetachFrom
 FlashMCU
 IssueReset
 LaunchStage1
 Log
 NoisyLog
 ReadApplicationVersion
 ReadCommonErrorStatus
 ReadCommonSystemStatus
 ReadFeature1StatusBits
 ReadFeature2StatusBits
 ReadFirmwareVersionHigh
 ReadFirmwareVersionLow
 ReadHardwareVersion
 ReadMagicNumber
```

2. To see full signatures of methods just enter the controller name and press enter:

```
host.HPSHostController
```

You will see more detailed output

```
The following methods are available:
 - Void AttachTo (II2CPeripheral obj)
 - Void DebugLog (String message)
 - Void DetachFrom (II2CPeripheral obj)
 - Void FlashMCU (String path)
 - Void IssueReset ()
 - Void LaunchStage1 ()
 - Void Log (LogLevel type, String message)
 - Void NoisyLog (String message)
 - Byte[] ReadApplicationVersion (TimeInterval timeInterval)
 - String[,] ReadCommonErrorStatus (TimeInterval timeInterval)
 - String[,] ReadCommonSystemStatus (TimeInterval timeInterval)
 - Byte[] ReadFeature1StatusBits (TimeInterval timeInterval)
 - Byte[] ReadFeature2StatusBits (TimeInterval timeInterval)
 - Byte[] ReadFirmwareVersionHigh (TimeInterval timeInterval)
 - Byte[] ReadFirmwareVersionLow (TimeInterval timeInterval)
 - Byte[] ReadHardwareVersion (TimeInterval timeInterval)
 - Byte[] ReadMagicNumber (TimeInterval timeInterval)
Usage:
 host.HPSHostController MethodName param1 param2 ...
```

3. To execute an action with the host controller:

```
host.HPSHostController ReadMagicNumber "1.0"
```

> Note: The "1.0" is the time for the controller will wait for data from the slave; if there is no data, a zero will be returned. This API is not yet final, but this solution allows us to prevent Renode hanging in case the software does not return information.

## Example test scenario, with both binaries (stage0 and stage1) loaded:

Commands to execute:
```
host.HPSHostController ReadCommonSystemStatus "1.0"	# (verify status register before stage1 launch)
host.HPSHostController ReadCommonErrorStatus "1.0"	# (verify error register before stage1 launch)
host.HPSHostController LaunchStage1
host.HPSHostController ReadCommonSystemStatus "1.0"	# (verify status register after stage1 launch)
host.HPSHostController ReadCommonErrorStatus "1.0"	# (verify error register after stage1 launch)
host.HPSHostController ReadMagicNumber "1.0"
```

## Example test scenario with only stage0 loaded initially, and stage1 loaded from stage0:

Commands to execute:
```
host.HPSHostController ReadCommonSystemStatus "1.0"		# (verify that stage1 is missing)
sysbus ReadDoubleWord 0x08010000				        # (inspect memory under which stage1 should be present)
host.HPSHostController FlashMCU @path-to-file/stage1_app.bin	# (this may take some time)
sysbus ReadDoubleWord 0x08010000				        # (again inspect memory under which stage1 should be present)
host.HPSHostController IssueReset
# Leave some short time for the reset to finish
host.HPSHostController LaunchStage1
host.HPSHostController ReadCommonSystemStatus "1.0"	    # (verify status register after stage1 launch)
host.HPSHostController ReadCommonErrorStatus "1.0"	    # (verify error register after stage1 launch)
host.HPSHostController ReadMagicNumber "1.0"
```

## Running robot test

To execute automated test in Renode from the provided Robot file, run:

```
./renode-test hps.robot
```
You should see the following as a result:
```
Preparing suites
Started Renode instance on port 9999; pid 1535502
Starting suites
Running hps.robot
+++++ Starting test 'hps.Should Launch Stage1'
+++++ Finished test 'hps.Should Launch Stage1' in 55.14 seconds with status OK
Cleaning up suites
Closing Renode pid 1535502
Aggregating all robot results
Output:  /{path-to}/robot_output.xml
Log:     /{path-to}/log.html
Report:  /{path-to}/report.html
Tests finished successfully :)
```

For detailed results, see the created ``results.html``.

## Inspection and debugging

1. Inspect and configure log level of the platform, and/or set it for a specific peripheral:

```
logLevel			        # (displays log level settings)
logLevel -1 sysbus.i2c1		# (set level to NOISY for I2C1)
```

(Note: use the ``peripherals`` command to display available peripherals)

More details on logger usage in [the documentation](https://renode.readthedocs.io/en/latest/basic/logger.html).

2. Enable logging access (R/W) to a peripheral:

```
sysbus LogPeripheralAccess sysbus.i2c1
```

Log all accesses to peripherals:

```
sysbus LogAllPeripheralsAccess true
```

3. Starting GDB

To start up GDB, run the server on a selected port (here: 3333):

```
machine StartGDBServer 3333
```

Then connect from the host as usual:

```
(gdb) target remote :3333
```

> Note: You can use breakpoints, stepping etc, but you still need to start the simulation with the ``start`` command

> Note: You can issue Monitor commands from the GDB level:
>
> ```
> (gdb) mon host.HPSHostController ReadCommonSystemStatus "1.0"
> ```

