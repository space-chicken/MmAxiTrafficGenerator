# MmAxiTrafficGenerator
A simple traffic generator with an AXI4 memory-mapped interface that can be used for performance testing, simulation and circuit verification.

# Key feature and benefits:
- Support AXI4 memory-mapped interface
- Support linear and pseudo-random accesses with address update after each burst
- Burst length can by dynamically changed
- Supported burst lengths are 32, 64, 128, 256, 512, 1024, 2048 or 4096 bytes
- Optional transfer start and stop time capture 
  
# Parameters
|Parameter name|Default value|Description|
|---|---|---|
|G_TIMEBASE_WIDTH|32|Timebase register width|
|G_ADDRESS_WIDTH|32|Start and bondary addresses register width|
|G_COUNTERS_WIDTH|32|Transfer counters width|
|G_AXI_DATA_WIDTH|128|AXI data bus width|
|G_AXI_ADDR_WIDTH|49|AXI address width|

# Results
## Read channel
A waveform of 4x read transactions (burst size is 64 bytes) with sequential address generation is shown below:
![Sequential read transactions](https://github.com/space-chicken/MmAxiTrafficGenerator/blob/2683fcebc3f278e7d375e943a27233915ee31382/Doc/waveforms/read_sequential.png?raw=true)

A waveform of 4x read transactions (burst size is 64 bytes) with random address generation is shown below:
![Random read transactions](https://github.com/space-chicken/MmAxiTrafficGenerator/blob/2683fcebc3f278e7d375e943a27233915ee31382/Doc/waveforms/read_random.png?raw=true)

## Write channel 
A waveform of 4x write transactions (burst size is 64 bytes) with sequential address generation is shown below:
![Sequential write transactions](https://github.com/space-chicken/MmAxiTrafficGenerator/blob/2683fcebc3f278e7d375e943a27233915ee31382/Doc/waveforms/write_sequential.png?raw=true)

A waveform of 4x write transactions (burst size is 64 bytes) with random address generation is shown below:
![Random write transactions](https://github.com/space-chicken/MmAxiTrafficGenerator/blob/2683fcebc3f278e7d375e943a27233915ee31382/Doc/waveforms/write_random.png?raw=true)