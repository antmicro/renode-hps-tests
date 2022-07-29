*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Variables ***
${UART}                       sysbus.uart

*** Keywords ***
Create Machine
    [Arguments]  ${stage0}
    Create Log Tester         5

    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/stm32g0.repl

    Execute Command           machine LoadPlatformDescriptionFromString "camera: I2C.DummyI2CSlave @ i2c2 0x24 { Register0Value: 0x01; Register1Value: 0xB0 }"
    Execute Command           machine LoadPlatformDescriptionFromString "flashSpi: SPI.GigaDevice_GD25LQ @ spi1 { underlyingMemory: flash }"
    Execute Command           machine LoadPlatformDescriptionFromString "cs: Miscellaneous.Button @ gpioPortA 8 { -> gpioPortA@8 }"
    Execute Command           machine LoadPlatformDescriptionFromString "fpgaProgram_led: Miscellaneous.LED @ gpioPortC 15"
    Execute Command           machine LoadPlatformDescriptionFromString "debug_led: Miscellaneous.LED @ gpioPortA 1"
    Execute Command           machine LoadPlatformDescriptionFromString "gpioPortC: { 15 -> fpgaProgram_led@0 }"
    Execute Command           machine LoadPlatformDescriptionFromString "gpioPortA: { 1 -> debug_led@0 }"
    Execute Command           machine LoadPlatformDescriptionFromString "gpioPortB: { 0 -> flashSpi@0 }"

    Execute Command           macro reset "sysbus LoadELF @${stage0}"
    Execute Command           runMacro $reset

    Execute Command           emulation AddHPSHostController
    Execute Command           connector Connect sysbus.i2c1 host.HPSHostController

*** Test Cases ***
Should Launch Stage1
    Create Machine            ${CURDIR}/stage0
    Start Emulation

    Sleep                     1
    ${status}=                Execute Command           host.HPSHostController ReadSystemStatus "1.0"             # (verify that stage1 is missing)

    Should Contain            ${status}                 |1${SPACE*4}|5${SPACE*2}|WPOFF${SPACE*13}|Write protect pin off${SPACE*30}|
    Should Contain            ${status}                 |0${SPACE*4}|4${SPACE*2}|WPON${SPACE*14}|Write protect pin on${SPACE*31}|
    Should Contain            ${status}                 |1${SPACE*4}|3${SPACE*2}|STAGE0${SPACE*12}|Stage 0 is running${SPACE*33}|
    Should Contain            ${status}                 |${SPACE*5}|2${SPACE*2}|${SPACE*18}|${SPACE*51}|
    Should Contain            ${status}                 |0${SPACE*4}|1${SPACE*2}|FAULT${SPACE*13}|System has an unrecoverable fault${SPACE*18}|
    Should Contain            ${status}                 |1${SPACE*4}|0${SPACE*2}|OK${SPACE*16}|System is operational${SPACE*30}|

    ${val}=                   Execute Command           sysbus ReadDoubleWord 0x0800A000				                # (inspect memory under which stage1 should be present)
    Should Contain            ${val}                    0x00000000

    Execute Command           host.HPSHostController FlashMCU @${CURDIR}/stage1_app.bin                    # (this may take some time)

    Sleep                     1
    ${val}=                   Execute Command           sysbus ReadDoubleWord 0x0800A000				                # (again inspect memory under which stage1 should be present)
    Should Contain            ${val}                    0x0C03FEFE

    Execute Command           host.HPSHostController CommandIssueReset
    Sleep                     10s                                                                                       # (leave some time for the reset to finish)

    Execute Command           host.HPSHostController CommandLaunchStage1
    Sleep                     5

    ${status}=                Execute Command           host.HPSHostController ReadSystemStatus "1.0"                   # (verify status register after stage1 launch)

    Should Contain            ${status}                 |1${SPACE*4}|11${SPACE*1}|STAGE0_LOCKED${SPACE*5}|Whether stage0 has been make read-only${SPACE*13}|
    Should Contain            ${status}                 |0${SPACE*4}|10${SPACE*1}|CMDINPROGRESS${SPACE*5}|A command is in-progress${SPACE*27}|
    Should Contain            ${status}                 |0${SPACE*4}|9${SPACE*2}|APPLREADY${SPACE*9}|Application is running, and features may be enabled|
    Should Contain            ${status}                 |1${SPACE*4}|8${SPACE*2}|APPLRUN${SPACE*11}|Stage 1 has been launched, and is now running${SPACE*6}|
    Should Contain            ${status}                 |${SPACE*5}|7${SPACE*2}|${SPACE*18}|${SPACE*51}|
    Should Contain            ${status}                 |${SPACE*5}|6${SPACE*2}|${SPACE*18}|${SPACE*51}|
    Should Contain            ${status}                 |0${SPACE*4}|5${SPACE*2}|WPOFF${SPACE*13}|Write protect pin off${SPACE*30}|
    Should Contain            ${status}                 |0${SPACE*4}|4${SPACE*2}|WPON${SPACE*14}|Write protect pin on${SPACE*31}|
    Should Contain            ${status}                 |0${SPACE*4}|3${SPACE*2}|STAGE0${SPACE*12}|Stage 0 is running${SPACE*33}|
    Should Contain            ${status}                 |${SPACE*5}|2${SPACE*2}|${SPACE*18}|${SPACE*51}|
    Should Contain            ${status}                 |0${SPACE*4}|1${SPACE*2}|FAULT${SPACE*13}|System has an unrecoverable fault${SPACE*18}|
    Should Contain            ${status}                 |1${SPACE*4}|0${SPACE*2}|OK${SPACE*16}|System is operational${SPACE*30}|

    ${status}=                Execute Command           host.HPSHostController ReadError "1.0"                          # (verify error register after stage1 launch)

    Should Match Regexp       ${status}                 |0\\+ |9\\+ |BUFORUN\\+ |Buffer overrun\\+ |
    Should Match Regexp       ${status}                 |0\\+ |8\\+ |BUFNAVAIL|Buffer not available\\+ |
    Should Match Regexp       ${status}                 |0\\+ |7\\+ |I2CBADREQ|A bad I2C request was made|
    Should Match Regexp       ${status}                 |0\\+ |6\\+ |SPIFLASH\\+ |SPI flash access failed\\+ |
    Should Match Regexp       ${status}                 |0\\+ |5\\+ |CAMERA\\+ |Camera not functional\\+ |
    Should Match Regexp       ${status}                 |0\\+ |4\\+ |I2CORUN\\+ |I2C overrun\\+ |
    Should Match Regexp       ${status}                 |0\\+ |3\\+ |I2CBERR\\+ |I2C bus error\\+ |
    Should Match Regexp       ${status}                 |0\\+ |2\\+ |PANIC\\+ |A panic occurred\\+ |
    Should Match Regexp       ${status}                 |0\\+ |1\\+ |MCUFLASH\\+ |Error writing to MCU flash|
    Should Match Regexp       ${status}                 |0\\+ |0\\+ |I2CURUN\\+ |I2C underrun\\+ |

    ${status}=                Execute Command           host.HPSHostController ReadMagicNumber "1.0"
    Should Contain            ${status}                 0x9D, 0xF2