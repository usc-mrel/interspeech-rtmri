## State-of-the-art speech production MRI protocol for new 0.55 Tesla scanners

[![DOI](https://zenodo.org/badge/810527636.svg)](https://zenodo.org/doi/10.5281/zenodo.12751560)

Code accompanying Interspeech 2024 Submission

The following code is split into three separate code-bases. Some of them are separate github repositories linked in this README document.
- Pulse Sequence generation in pulseq
- Python-based online image reconstruction using the Siemens FIRE interface
- Offline MATLAB-based image reconstruction using collected raw data.

One example dataset can be found at [this link](https://drive.google.com/drive/folders/1ZP3Ztb4DEi4iH6kdqNjPRvvTDhjDGXLy?usp=drive_link). If you have issues, please contact prakashk@usc.edu.
Please also download the trajectory file at [this link](https://drive.google.com/file/d/1zoVTQ19sXUpN-9iILz7IFSXZPdNbktgp/view?usp=sharing) and put it in the trajectory/ folder.

### Pulse Sequence Generation
Pulse Sequence generation code requires code from [this repository](https://github.com/usc-mrel/rtspiral_pypulseq).
The code points to a `config.toml` file, for which relevant config.toml files are in this repository, in the `pulseq_configs` folder.
The code will output trajectory files into a folder. 

### Python-based online image reconstruction
Online image reconstruction can be done using the Siemens FIRE interface. Code can be found at this [location](https://github.com/usc-mrel/python-ismrmrd-server). This repository does not include instructions on how to install the FIRE interface on your own scanner, and you must contact Siemens for help with this. However, once you have a working connection to a linux or docker container, you can simply set the config in the header to be `simplenufft1arm`. Double check that the trajectory files outputted by the pulse sequence generation are in a folder called `seq_meta`, otherwise you will receive an error. 

### Offline MATLAB-based image reconstruction
Dependencies:
- USC dynamic reconstruction toolbox: [link](https://github.com/usc-mrel/usc_dynamic_reconstruction).
- ISMRMRD: [link](https://github.com/ismrmrd/ismrmrd).

Please install the repository into your computer and add its path and all subdirectories to your MATLAB path.
We have included an example rawdata file in this repository for your convenience in order to reconstruct the data using this reconstruction script.

In order to run our test reconstruction script, please run `matlab/reconstruct_STCR_2d.m`
