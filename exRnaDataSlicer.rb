#!/usr/bin/env ruby
#
# exRnaDataSlicer.rb This program will provide coverage from given region of interst Bed file and the the selected exRNA Atlas biosamples.
#
# Usage:  ruby exRnaDataSlicer.rb [options]
#     -b, --bed bedFile                Path to the region of interest Bed file for intersection
#     -s, --samples sampleFile         Path to the sample files, tab delimited format: each row with [analysis ID]\t[biosampleID]
#     -o, --out outputPath             Designate output path (default at the current locaiton)
#     -n, --filename outputName        The name of the output file (default as exRNA_data_slice_combined.bed)
#     -m, --multirun                   Keep intermediate files to speed up the future run time
#         --nocleanup                  Keep the tmp directory and do not remove anything
#     -h, --help                       Display this screen
#
#
# author: David Chen
# email: dc12@bcm.edu

require 'uri'
require 'json'
require 'optparse'

def getAllJobsJson(outfile)
  string = "https://genboree.org/REST/v1/grp/Extracellular%20RNA%20Atlas/kb/exRNA-atlas-v4/coll/Jobs/docs"
  `curl --silent "#{string}" -o #{outfile}`
end

def curlAtlasApi(docType, docName, outfile)
  string = "https://genboree.org/REST/v1/grp/Extracellular%20RNA%20Atlas/kb/exRNA-atlas-v4/coll/#{docType}/doc/#{docName}"
  `curl --silent "#{string}" -o #{outfile}`
end

def curlFtpFile(ftpPath, outfile)
  puts "curl --silent \"#{ftpPath}\" -o #{outfile}"
  `curl --silent "#{ftpPath}" -o #{outfile}`
end

def getFromJson(data,query)
  query.split('.').inject(data) { |memo,key|
    key = key.to_i if memo.is_a?(Array)
    memo.fetch(key)
  }
end

def checkJsonStatus?(jsonFile,doc)
  return TRUE if getFromJson(jsonFile, 'status.msg').match(/ok/i)
  puts "something went wrong while requesting for Doc: #{doc}"
  return FALSE
end

def readFileToJson(file)
  puts "#{file} not found" unless File.exist?(file)
  return JSON.load(File.read(file))
end

def foundRightJson?(json, analysis)
  return TRUE if getFromJson(json, 'data.Job.properties.Related Analysis.value') == analysis
  return FALSE
end

def foundRightRelatedBiosample?(json, biosample)
  return TRUE if getFromJson(json, "Related Biosample.value") == biosample
  return FALSE
end

def decompressBedgraphXZ(xzFile)
  if File.exist?(xzFile)
    `xz -d #{xzFile}`
    return TRUE
  else
    puts ""
    puts "Warning: The xz file: #{xzFile} does not exist!"
    puts ""
  end
  return FALSE
end

def fileExists?(path,filetype)
  return TRUE if File.exist?(path)
  puts "#{filetype}: #{path} does not exist"
  return FALSE
end

def readSampleFile(sampleFile)
  output = {}
  File.foreach(sampleFile) { |line|
    next if line.match(/biosample|analysis/i)
    tmp = line.chomp.split("\t")
    output[tmp[1]] = tmp[0]
  }
  return output
end

def cleanup(workPath)
  Dir["#{workPath}/*"].each { |entry|
    if File.directory?(entry)
      cleanup(entry)
    else
      File.delete("#{entry}")
    end
  }
  Dir.delete("#{workPath}")
end

options = {}
optparse = OptionParser.new { |opts|
  opts.banner = "Usage:  ruby #{File.basename(__FILE__)} [options]\n"
  opts.on('-b', '--bed bedFile', "Path to the region of interest Bed file for intersection") {|bed| options[:bed]=bed }
  opts.on('-s', '--samples sampleFile', "Path to the sample files, tab delimited format: each row with [analysis ID]\\t[biosampleID]") { |samples| options[:samples]=samples}
  opts.on('-o', '--out outputPath', "Designate output path (default at the current locaiton)") {|out| options[:out]=out}
  opts.on('-n', '--filename outputName', "The name of the output file (default as exRNA_data_slice_combined.bed)") {|fname| options[:fname]=fname}
  opts.on('-m', '--multirun', "Keep intermediate files to speed up the future run time") { options[:multirun]= true}
  opts.on('--nocleanup', "Keep the tmp directory and do not remove anything") {options[:nocleanup] = true}
  opts.on('-h', '--help', "Display this screen"){ puts optparse; exit }
}
optparse.parse!

workingPath = Dir.pwd
workingPath = options[:out] if options[:out]
tmpPath = "#{workingPath}/tmp"
bedgraphPath = "#{tmpPath}/bedgraphs"
Dir.mkdir(tmpPath) unless File.directory?(tmpPath)
Dir.mkdir(bedgraphPath) unless File.directory?(bedgraphPath)

#check for the required parameters are passed in
if options[:bed].nil?
  puts "A region of interest bed file is required.  It can be passed in by using [-b|--bed] [path to bed]"
  puts ""
  puts optparse
  exit(1)
end
if options[:samples].nil?
  puts "A tsv for the samples is required.  It can be passed in by using [-s|--samples] [path to sample file]"
  puts ""
  puts optparse
  exit(1)
end

sampleFile = options[:samples]
roi = options[:bed]

puts "Using roi bed file: #{roi}"
puts "Using sample file: #{sampleFile}"
puts "Using output directory: #{workingPath}"

exit (1) unless fileExists?(roi,"ROI")  #make sure input file is there
exit(1) unless fileExists?(sampleFile, "Samples") #make sure input file is there

alljobsFile = "#{tmpPath}/alljobs.json"
getAllJobsJson(alljobsFile) unless File.exist?(alljobsFile)
allJobs = readFileToJson(alljobsFile)
#make sure the name of the jobs could be found, otherwise exit
exit(1) unless checkJsonStatus?(allJobs, "All Jobs")

failed = []
samples = readSampleFile(sampleFile)
#locate and download the bedgraphs
samples.each { |biosample, analysis|
  bedgraphfile = "#{bedgraphPath}/#{biosample}_endogenousAlignments_genome_Aligned.bedgraph"
  puts "Looking for #{biosample} bedgraph file: #{bedgraphfile}"
  if File.exist?(bedgraphfile)
    puts "#{bedgraphfile} exists already.. move on to the next"
    next
  end
  puts "#{bedgraphfile} was not found.  Need to find the ftp path."
  jobFound = FALSE
  getFromJson(allJobs,"data").each { |item|
    docName = getFromJson(item,"Job.value")
    jobfile = "#{tmpPath}/#{docName}.metadata.tsv"
    next if docName.match(/PCR/)
    curlAtlasApi(:Jobs,docName,jobfile) unless File.exist?(jobfile)
    docJson = readFileToJson(jobfile)
    next unless checkJsonStatus?( docJson,docName ) #make sure the docName was retrieved correctly
    next unless foundRightJson?( docJson,analysis )
    puts "Found the correct FTPjob for the analysis: #{docName} and downloaded the doc file: #{jobfile}"
    jobFound = TRUE
    getFromJson( docJson,"data.Job.properties.Related Biosamples.items").each { |relatedBiosample|
      next unless foundRightRelatedBiosample?(relatedBiosample,biosample)
      relatedResultFiles =  getFromJson(relatedBiosample,"Related Biosample.properties.Related Result Files.value")
      rfFile = "#{tmpPath}/#{relatedResultFiles}.metadata.tsv"
      puts "Found result file doc.. download doc: #{rfFile}"
      curlAtlasApi("Result Files",relatedResultFiles,rfFile) unless File.exist?(rfFile)
      rfJson = readFileToJson(rfFile)
      next unless checkJsonStatus?(rfJson, relatedResultFiles) #make sure the result files doc was retrieved correctly
      getFromJson(rfJson,"data.Result Files.properties.Biosample ID.properties.Pipeline Result Files.items").each { |file|
        next unless getFromJson(file,"File ID.properties.File Name.value") == "endogenousAlignments_genome_Aligned.bedgraph.xz"
        bedgraphuri = URI(getFromJson(file,"File ID.properties.Genboree URL.value"))
        bedgraphXzFile = "#{bedgraphPath}/#{biosample}_#{File.basename(bedgraphuri.to_s)}"
        puts "downlaoding bedgraph.xz file: #{bedgraphXzFile}"
        curlFtpFile(bedgraphuri.to_s, bedgraphXzFile)
        if decompressBedgraphXZ(bedgraphXzFile) #decompressedBedgraphXZ will check if the file does exist prior to decompressing the file
          puts "#{bedgraphXzFile} has been decompressed."
        else
          failed << "Failed to download bedgraph for #{biosample}"
        end
      }
    }
  }
  unless jobFound
    failed << failed << "Failed to download bedgraph for #{biosample}"
    puts ""
    puts "Warning: Cannot find the Job file for analysis: #{analysis}, biosample: #{biosample}."
    puts "Please check to make sure if the IDs for the analysis and the biosamples are correct."
    puts ""
  end
}

# make sure the roi file is sorted
sortedBedPath = "#{tmpPath}/sortedBed"
Dir.mkdir(sortedBedPath) unless File.directory?(sortedBedPath)
roiFname = File.basename(roi, File.extname(roi))
sortedBedFile = "#{sortedBedPath}/#{roiFname}_sorted#{File.extname(roi)}"
puts "Sorting the given roi bed file #{roi} and store it as #{sortedBedFile}"
puts "sort -k1,1 -k2,2n #{roi} > #{sortedBedFile}"
`sort -k1,1 -k2,2n #{roi} > #{sortedBedFile}`

# create intersection of the roi with bedgraphs
intersectPath = "#{tmpPath}/ind_intersection"
Dir.mkdir(intersectPath) unless File.directory?(intersectPath)
codePath = File.dirname(__FILE__)
#gather all of the bedgraphs
Dir["#{bedgraphPath}/*bedgraph"].each { |bedgraph|
  puts "intersecting sorted roi: #{sortedBedFile} with bedgraph: #{bedgraph} "
  fname = File.basename(bedgraph)
  system("sh #{codePath}/dataSlicerHelper.sh -r #{sortedBedFile} -b #{bedgraph} -i -o #{intersectPath}/#{fname}_intersect.bed")
  checkfailed = $?.exitstatus == 1
  failed << "Intersecting bedgraph: #{bedgraph} with sortedBedFile: #{sortedBedFile}" if checkfailed
}

# gather the intersection paths and merge all together
paths = []
names = []
Dir["#{intersectPath}/*bed"].each { |file|
  paths << file
  names << File.basename(file).split("_endogenousAlignments")[0]
}
outName = "exRNA_data_slice_combined.bed"
outName = options[:fname] if options[:fname]

puts "Merge intersections"
system("sh #{codePath}/dataSlicerHelper.sh -n \"#{names.join(' ')}\" -b \"#{paths.join(' ')}\" -m -o #{workingPath}/#{outName}")
checkfailed = $?.exitstatus == 1
failed << "Merging intersections" if checkfailed

unless options[:nocleanup]
  puts "Clean up:"
  if options[:multirun]
    puts "Removing intermiediate files in #{tmpPath}/bedgraphs and #{tmpPath}/ind_intersection"
    cleanup(bedgraphPath)
    cleanup(sortedBedPath)
    cleanup(intersectPath)
  else
    puts "Remove the all of the intermediate files"
    cleanup(tmpPath)
  end
end

# checks to see if any error was encounterred
if failed.size > 0
  puts ""
  puts "Error(s):"
  failed.each { |f| puts f}
  puts ""
else
  puts "Finish."
end
