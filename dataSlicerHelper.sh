#!/usr/bin/bash
module load BEDTools/2.17

# you can specify the path to bedtools in the next line and comment out line 2 if your system is not set up the same to load the module
bedtools_cmd="bedtools"

usage()
{
  echo "Usage: sh `basename $0` [-r <path to roi>] [-b <bedgraph location/path>] [-o <output file>] [-i (for inersection)] [-m (for merging intersections)] [-n <list of header names>]"
}

while getopts "r:b:o:imn:" params
do
  case $params in
  r) rbp=$OPTARG;;
  b) bedgraph=$OPTARG;;
  o) output=$OPTARG;;
  i) intersection="true";;
  m) combine="true";;
  n) names=$OPTARG;;
  ?) usage
    exit
    ;;
  esac
done
shift $((OPTIND-1))

if [[ $combine == "true" ]]; then
  echo "${bedtools_cmd} unionbedg -i $bedgraph -header -names $names > ${output}"
  ${bedtools_cmd} unionbedg -i ${bedgraph} -header -names ${names} > ${output}
elif [[ $intersection == "true" ]]; then
  echo "${bedtools_cmd} map -a ${rbp} -b ${bedgraph} -c 4 | awk '\$4!~ /\./' | sed -e 's/\./0/g' > ${output}"
  ${bedtools_cmd} map -a ${rbp} -b ${bedgraph} -c 4 | sed -e 's/\./0/g' > ${output}
fi