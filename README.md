## State-of-the-art speech production MRI protocol for new 0.55 Tesla scanners

Code accompanying Interspeech 2024 Submission

The following code is split into three separate code-bases. Some of them are separate github repositories linked in this README document.
- Pulse Sequence generation in pulseq
- Python-based online image reconstruction using the Siemens FIRE interface
- Offline MATLAB-based image reconstruction using collected raw data.

### Pulse Sequence Generation
Pulse Sequence generation code requires code from [](this repository).
The code points to a `config.toml` file, for which relevant config.toml files are in this repository.
The code will output trajectory files into a folder. 

### Python-based online image reconstruction
Online image reconstruction can be done using the Siemens FIRE interface. Code can be found at this [https://github.com/usc-mrel/python-ismrmrd-server](location). This repository does not include instructions on how to install the FIRE interface on your own scanner, and you must contact Siemens for help with this. However, once you have a working connection to a linux or docker container, you can simply set the config in the header to be `simplenufft1arm`. Double check that the trajectory files outputted by the pulse sequence generation are in a folder called `seq_meta`, otherwise you will receive an error. 

### Offline MATLAB-based image reconstruction
MATLAB reconstruction requires the usc_dynamic_reconstruction toolbox as a dependency [https://github.com/usc-mrel/usc_dynamic_reconstruction](linked here). Please install the repository into your computer and add its path and all subdirectories to your MATLAB path. We have included an example rawdata file in this repository for your convenience in order to reconstruct the data using this reconstruction script.

In order to run our test reconstruction script, please run matlab/reconstruct_STCR_2d.m
