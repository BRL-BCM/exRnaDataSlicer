# exRNA Data Slicer

---
This program will provide coverage from given region of interst bed file and the the selected exRNA Atlas biosamples

## Requirements

---
- BedTools version 2.17 or higher
- Ruby version 1.8.7 or higher
- Standard libraries are utilized
```
require 'uri'
require 'json'
require 'optparse'
```
## Getting Started

---
The program calls`bedtools`to create an intersection between the roi bed file and  the desired biosample bedgraph files.

Make sure bedtools is loaded and could be called by typing in`bedtools`in the command prompt. 
The program loads bedtools via module with`module load BEDTools/2.17`on line 2 in`dataSlicerHelper.sh`. It could be commented out with`#`and the path to bedtools could be set by modifying the variable `bedtools_cmd` on line 5 in`dataSlicerHelper.sh`.  
## Usage

---
```
 Usage:  ruby exRnaDataSlicer.rb [options]
     -b, --bed bedFile          Path to the region of interest Bed file for intersection
     -s, --samples sampleFile   Path to the sample files, tab delimited format: each row with [analysis ID]\t[biosampleID]
     -o, --out outputPath       Designate output path (default at the current locaiton)
     -n, --filename outputName  The name of the output file (default as exRNA_data_slice_combined.bed)
     -m, --multirun             Keep intermediate files to speed up the future run time
         --nocleanup            Keep the tmp directory and do not remove anything
     -h, --help                 Display this screen
```
### Running the program
The program will require two inputs: region of interest Bed file and list of samples in a tab delimited file.`-b` can be used to specify the region of interest Bed file and`-s` can be used to indicate the list of sample file.
```
ruby exRnaDataSlicer.rb -b roi.bed -s listOfSamples.txt
```
### Optional parameters
Additionally, there are other parameter which can be used to help running the program.  

`-o`can be used to indicate where you want the final output to be stored. The program will use your current location if this flag is not used.  It will also create a tempory directory in the outputPath for intermediate files. The temporty directory (./tmp) will be removed at the last step right before the program finishes.

`-n`can be used to specify the output file name. (It will be called exRNA_data_slice_combined.bed otherwise)

`-m`can be used to keep the intermediate files and increase the speed of the future runs. It will only remove the previously download bedgraphs and intersected files when the program finishes.

## Input Files

---
### Region of interest bed file
Bed file is formed by 3 columns of chromosome, start, stop coodinates separated by a tab between each columns.  The coordinates from the region of interest would require to be in **hg19** since the Atlas samples used hg19 as a reference. Headers are optional but they must start with a `#` at the beginning of the line.

Example of a bed file:
```
chr1    892273  892330
chr1    934978  935038
chr1    955724  955739
chr1    978909  978973
chr1    981527  981562
chr1    982341  982404
```
### List of samples
The sample list will start with a header column of Analysis and Biosamples then followed by individual rows of analysis IDs and biosamples IDs. This is also a tab delimited file.  The analysis ID and  biosamples ID of the exRNA data can be found from [exRNA Atlas](https://exrna-atlas.org/) under the gridview of the studies ([Overview of Studies](https://exrna-atlas.org/#datasetsSummaryAnchor) -> [exRNA Profiling Datasets](https://exrna-atlas.org/genboreeKB/projects/extracellular-rna-atlas-v2/exat/datasets) -> select inidividual dataset to view more information in the grid view).

Example of a sample list:
```
Analysis    Biosample
EXR-KJENS17CZMbP-AN EXR-KJENS1VOL009-BS
EXR-AKRIC157ITEl-AN EXR-AKRIC1AKGBM001-BS
EXR-AKRIC157ITEl-AN EXR-AKRIC1AKGBM003-BS  
EXR-AKRIC157ITEl-AN EXR-AKRIC1AKGBM004-BS
```
## Output File

---
The output file is defaulted to be stored as exRNA_data_slice_combined.bed in the working path specified by the user or the directory where the program was ran.

It will have a header column as the first line and the region of interest with coverage of the selected samples starting from the second line.

Example of an output:
```
chrom   start   end EXR-KJENS1VOL009-BS EXR-AKRIC1AKGBM001-BS   EXR-AKRIC1AKGBM003-BS   EXR-AKRIC1AKGBM004-BS
chr1    988562  988620  0   0   0   0
chr1    988620  988676  0   0   0   0
chr1    988680  988743  0   0   0   0
chr1    3639314 3639429 0   0   0   0
chr1    3639560 3639630 0   0   0   0
```
## Catching Errors

---
If an instance comes up where a biosample bedgraph could not be downloaded or problems with either the intersection and merging, the output will display where there was an issue to make it easier to trouble shoot.  Please contact us if you cannot reslove it or needs additional assisitance.

It will display `Finish.` on the last line if everything ran smoothly.

Example where an error occured during the merging process:
```
Error(s):
Merging intersections

```

## Improvement Ideas

---
- All ideas have been implemented at this point.