# Workflow reproducing bug of IRQ not being issued

## Extra code change

Before running Renode, we need to add some extra code in some files to make it work.

### Replace code of the following files into the corresponding location
- code_change/GigaDevice_GD25LQ.cs --> renode-infrastructure/src/Emulator/Peripherals/Peripherals/SPI/GigaDevice_GD25LQ.cs

- code_change/DecodedOperation.cs --> renode-infrastructure/src/Emulator/Peripherals/Peripherals/SPI/NORFlash/DecodedOperation.cs

### Add this following function into `src/Emulator/Peripherals/Peripherals/Mocks/HPSHostController.cs`

```cs
        public void FlashSPI(ReadFilePath path)
        {
            var address = 0;
            var data = new byte[256 + 5];
            data[0] = ((byte)Commands.WriteMemory << 6) | (byte)MemoryBanks.SPIFlash;

            var bytes = File.ReadAllBytes(path);
            var left = bytes.Length;

            while(left > 0)
            {
                var batchSize = Math.Min(left, 256);
                Array.Copy(bytes, address, data, 5, batchSize);
                data[1] = (byte)(address >> 24);
                data[2] = (byte)(address >> 16);
                data[3] = (byte)(address >> 8);
                data[4] = (byte)address;
                IssueCommand(data);

                currentSlave.Read(0);
                // Poll until all the bytes are written
                PollForRegisterBit(RegisterBitName.RXNE);

                address += 256;
                left -= batchSize;

                // If the error occurs, you should see this keep being printed but nothing from system logs. 
                Console.WriteLine("next " + address);
            }
        }
```

## Running renode
After all the necessary code change, run `./build.sh` .

To make this easier, the resc file included all the commands needed to run to reproduce the issue. 
Simply do
```
renode
```

Then inside renode run:

```
LogLevel -1 #inside noisy log you can see that 
include @hps_debug.resc
```

Note: there's an up to date `stage1_app` inside the `hps_spi_flash_issue/`, please do not use the old one in case there's any conflicts.