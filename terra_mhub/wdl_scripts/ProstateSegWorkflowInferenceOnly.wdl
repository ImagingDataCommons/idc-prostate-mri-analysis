	# This WDL script is designed to run any models abstracted by mhubai
	# This wdl workflow takes several inputs including the model name, custom configuration file, and resource specifications (CPUs, RAM, GPU type).
	# It then calls the task (mhubai_terra_runner) with these inputs.

	# The mhubai_terra_runner task first installs necessary tools (s5cmd for data download and lz4 for compression),
	# then downloads the data from either AWS S3 or Google Cloud Storage (GCS).
	# After that, it runs the models using the mhubio.run command with the provided model name and configuration file.
	# Finally, it compresses the output data and moves it to the Cromwell root directory.

	# The runtime attributes specify the Docker image to use, CPU and memory resources, disk type and size,
	# number of preemptible tries and retries, GPU type and count, and the zones where to run the task.

	version 1.0
	#WORKFLOW DEFINITION
	workflow mhubai_workflow {
		input {
				#all the inputs entered here but not hardcoded will appear in the UI as required fields
				#And the hardcoded inputs will appear as optional to override the values entered here

				##Combination variables -- indicate whole prostate gland code
				Array[String] dicomCodeValuesProstate_lst
				Array[String] dicomCodeMeaningProstate_lst
				Array[String] dicomCodingSchemeDesignatorProstate_lst

				#radiomics computation variables
				## compute radiomics for every segment available
				### AI DICOM SEG parameters
				Array[String] dicomSrAiCodeValues_lst
				Array[String] dicomSrAiCodeMeaning_lst
				Array[String] dicomSrAiCodingSchemeDesignator_lst

				#IDC serieUIDs parameters
				Array[String] seriesInstanceUIDs
				Array[String] adcSeriesInstanceUIDs
				String collection_id

				#mhub
				Array[String] mhub_model_name_lst
				Array[File] mhubai_custom_config_lst
				Array[String] mhubaiCustomSegmentAlgorithmName_lst

				#resampling scheme
				String res_scheme_format

				#VM Config
				Int cpus = 4
				Int ram = 15
				Int preemptibleTries = 5
				Int maxRetries = 1
				String gpuType = 'nvidia-tesla-t4'
				String gpuZones = "europe-west2-a europe-west2-b asia-northeast1-a asia-northeast1-c asia-southeast1-a asia-southeast1-b asia-southeast1-c us-east4-a us-east4-b us-east4-c"
				String cpuZones = "asia-northeast2-a asia-northeast2-b asia-northeast2-c europe-west4-a europe-west4-b europe-west4-c europe-north1-a europe-north1-b europe-north1-c us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
		}
		  call ddl_idc_data {
			input:
				t2SeriesInstanceUIDs = seriesInstanceUIDs,
				adcSeriesInstanceUIDs = adcSeriesInstanceUIDs,
				cpus = cpus,
				cpuZones = cpuZones,
				ram = ram,
				preemptibleTries = preemptibleTries,
				maxRetries = maxRetries,
				docker = "cciausu1/prostate-analysis:v1"
		}
		scatter (idx in range(length(mhub_model_name_lst))) {
			#calling mhubai_terra_runner
			call mhubai_terra_runner {
				input:
					idcDataSingleModalFile = ddl_idc_data.idcSingleModalDataCompressedOutputFile,
					idcDataMultiModalFile = ddl_idc_data.idcMultiModalDataCompressedOutputFile,

					mhub_model_name = mhub_model_name_lst[idx],
					mhubai_custom_config = mhubai_custom_config_lst[idx],

					#mhubai dockerimages are predictable with the below format
					docker = "imagingdatacommons/"+mhub_model_name_lst[idx],

					cpus = cpus,
					ram = ram,
					preemptibleTries = preemptibleTries,
					maxRetries = maxRetries,
					gpuType = gpuType,
					gpuZones = gpuZones
			}
			call ai_combine_seg {
				input:
					MHUB_OUTPUT = mhubai_terra_runner.mhubCompressedOutputFile,
					mhubaiCustomSegmentAlgorithmName = mhubaiCustomSegmentAlgorithmName_lst[idx],
					dicomCodeValuesProstate_lst = dicomCodeValuesProstate_lst,
					dicomCodeMeaningProstate_lst = dicomCodeMeaningProstate_lst,
					dicomCodingSchemeDesignatorProstate_lst = dicomCodingSchemeDesignatorProstate_lst,
					res_scheme_format = res_scheme_format,
					cpus = cpus,
					ram = ram,
					preemptibleTries = preemptibleTries,
					maxRetries = maxRetries,
					cpuZones = cpuZones,
					docker = "cciausu1/prostate-analysis:v1"
			}
			call compute_radiomics as ai_rads{
				input:
					SEG_OUTPUT = ai_combine_seg.aiCombinationOutputFile,
					dicom_sr_CodeValues_lst = dicomSrAiCodeValues_lst,
					dicom_sr_codeMeaning_lst = dicomSrAiCodeMeaning_lst,
					dicom_sr_CodingSchemeDesignator_lst = dicomSrAiCodingSchemeDesignator_lst,
					terraRadSeriesDescription = mhub_model_name_lst[idx],
					res_scheme_format = res_scheme_format,
					cpus = cpus,
					ram = ram,
					preemptibleTries = preemptibleTries,
					maxRetries = maxRetries,
					cpuZones = cpuZones,
					docker = "cciausu1/prostate-analysis:v1"
			}
		  }
		call combine_outputs_inference {
				input:
				aiSegOutputFiles = ai_combine_seg.aiCombinationOutputFile,
				aiSrOutputFiles = ai_rads.radiomicsCompressedOutputFile,
				mhub_model_name_lst = mhub_model_name_lst,
				cpus = cpus,
				ram = ram,
				preemptibleTries = preemptibleTries,
				maxRetries = maxRetries,
				cpuZones = cpuZones,
				docker = "cciausu1/prostate-analysis:v1"
		}
	output {
        Array[File] mhubCompressedOutputFile = ai_combine_seg.aiCombinationOutputFile
        Array[File] radsAiCompressedOutputFile = ai_rads.radiomicsCompressedOutputFile
        File finalCompressedOutputFile = combine_outputs_inference.finalCompressedOutputFile
	}
}
	#Task Definitions
	task mhubai_terra_runner {
		input {
	  		#IDC image data data
				File idcDataSingleModalFile
				File idcDataMultiModalFile

				#mhub
	  		String mhub_model_name
	  		String mhubai_custom_config

	  		String docker

				#VM Config
				Int cpus
				Int ram
				Int preemptibleTries
				Int maxRetries
				String gpuType
				String gpuZones
		}
		command {
		# Install lz4 and tar for compressing output files
		apt-get update && apt-get install -y apt-utils lz4 pigz
		mkdir -p /app/data/input_data
		mkdir -p /app/data/output_data
		mkdir -p /app/raw_archives
		mkdir -p /app/raw_archives/single_modal
		mkdir -p /app/raw_archives/multi_modal
		#Unzip lz4 archives
		lz4 -dc < ~{idcDataMultiModalFile} | tar xvf - -C /app/raw_archives/multi_modal
		lz4 -dc < ~{idcDataSingleModalFile} | tar xvf - -C /app/raw_archives/single_modal
		#if model == multi-modal, need to have different input structure
		if [[ ~{mhub_model_name} == "nnunet_prostate_zonal_task05" ]]; then
			cp -r /app/raw_archives/multi_modal/sorted_data/* /app/data/input_data/
		else
			cp -r /app/raw_archives/single_modal/out_data/* /app/data/input_data/
		fi
		# mhub uses /app as the working directory, so we try to simulate the same
		cd /app
		# Run mhubio.run with the provided config or the default config
		wget https://raw.githubusercontent.com/vkt1414/mhubio/nonit/mhubio/run.py
		#download custom config if provided
		if [[ ~{mhubai_custom_config} != "default" ]]; then
			wget ~{mhubai_custom_config} -O /app/custom.yml
			python3 /app/run.py --config /app/custom.yml --print --debug
		else
			python3 /app/run.py --workflow default --print --debug
		fi
		# Compress output data and move it to Cromwell root directory
		tar -C /app/data -cvf - output_data | lz4 > /cromwell_root/output.tar.lz4
		}
		#Run time attributes:
		runtime {
			docker: docker
			cpu: cpus
			zones: gpuZones
			memory: ram + " GiB"
			bootDiskSizeGb: 50
			disks: "local-disk 10 HDD"
			preemptible: preemptibleTries
			maxRetries : maxRetries
			gpuType: gpuType
			gpuCount: 1
			nvidiaDriverVersion: "525.147.05"
		}
		output {
			File mhubCompressedOutputFile  = "output.tar.lz4"
		}
	}
	task ai_combine_seg{
		input {
			#PATH TO MHUB ZIP LZ4 INPUT containing DICOM SEG objects
			File MHUB_OUTPUT

			#custom SegmentAlgorithmName
			String mhubaiCustomSegmentAlgorithmName

			#Combination variables to form whole prostate gland
			#check if these codes are present, otherwise combine all segments
			Array[String] dicomCodeValuesProstate_lst
			Array[String] dicomCodeMeaningProstate_lst
			Array[String] dicomCodingSchemeDesignatorProstate_lst

			#Resampling parameters
			String res_scheme_format

			#docker image path
			String docker

			#VM Config
			String cpuZones
			Int cpus
			Int ram
			Int preemptibleTries
			Int maxRetries
		}
		command <<<
			#create output directories inside the VM
			mkdir -p /app/data
			mkdir -p /app/data/ai_combine
			cd /app/data
			pip3 install pyyaml
			python3 <<CODE
			import json
			import yaml
			#parse WDL variables into python variables
			dicomCodeValuesProstate_lst = "~{ sep=' ' dicomCodeValuesProstate_lst }".split()
			dicomCodeMeaningProstate_lst = "~{ sep=' ' dicomCodeMeaningProstate_lst }".split()
			dicomCodingSchemeDesignatorProstate_lst = "~{ sep=' ' dicomCodingSchemeDesignatorProstate_lst }".split()
			mhubaiCustomSegmentAlgorithmName = "~{mhubaiCustomSegmentAlgorithmName}"
			MHUB_OUTPUT = "~{MHUB_OUTPUT}"
			res_scheme_format = "~{res_scheme_format}"

			# Create a dictionary with the python variables
			data = {'dicomCodeValuesProstate_lst': dicomCodeValuesProstate_lst,
			'dicomCodeMeaningProstate_lst': dicomCodeMeaningProstate_lst,
			'dicomCodingSchemeDesignatorProstate_lst': dicomCodingSchemeDesignatorProstate_lst,
			'mhubaiCustomSegmentAlgorithmName': mhubaiCustomSegmentAlgorithmName,
			'MHUB_OUTPUT': MHUB_OUTPUT,
			'res_scheme_format': res_scheme_format,
			'OUTPUT_PATH': "/app/data/ai_combine"
			}
			# Write the dictionary to a JSON file
			with open("/app/data/params_eval.yaml", "w") as outfile:
					yaml.dump(data, outfile, indent=4, allow_unicode=True)
			CODE
			# #wget notebook from github
			cd /app/data
			wget https://raw.githubusercontent.com/ccosmin97/idc-prostate-mri-analysis/main/terra_mhub/papermill_data/ai_mhub_seg_dicom_combination.ipynb

			papermill /app/data/ai_mhub_seg_dicom_combination.ipynb /app/data/ai_mhub_seg_dicom_combination-output.ipynb -f /app/data/params_eval.yaml
			# notebook.ipynb -y 	paramters.yaml -o output.ipynb

			# Compress AI DICOM SEG and move it to Cromwell root directory
			mkdir -p /app/data/combination_archive
			mv /app/data/ai_combine/seg_prostate_gen /app/data/combination_archive/
			cp /app/data/ai_mhub_seg_dicom_combination-output.ipynb /app/data/combination_archive/.
			tar -C /app/data/ -cvf - combination_archive | lz4 > /cromwell_root/ai_combination_archive.tar.lz4
		>>>
		runtime {
			docker: docker
			cpu: cpus
			zones: cpuZones
			memory: ram + " GiB"
			bootDiskSizeGb: 50
			disks: "local-disk 10 HDD"
			preemptible: preemptibleTries
			maxRetries : maxRetries
		}
		output {
			File aiCombinationOutputFile  = "ai_combination_archive.tar.lz4"
		}
	}
	task compute_radiomics{
		input {
			#OUPUT from eval task taken here as input
			File SEG_OUTPUT

			#Parameters
			#list expert_serieUID
			Array[String] dicom_sr_CodeValues_lst
			Array[String] dicom_sr_codeMeaning_lst
			Array[String] dicom_sr_CodingSchemeDesignator_lst
			#custom SR SeriesDesription Prefix
			String terraRadSeriesDescription
			String res_scheme_format

			#docker image path
			String docker

			#VM Config
			String cpuZones
			Int cpus
			Int ram
			Int preemptibleTries
			Int maxRetries
		}
		command <<<
			mkdir -p /app/data
			mkdir -p /app/data/output_sr
			cd /app/data
			wget
			pip3 install pyyaml
			python3 <<CODE
			import json
			import yaml
			dicom_sr_CodeValues_lst = "~{ sep=' ' dicom_sr_CodeValues_lst }".split()
			dicom_sr_codeMeaning_lst = "~{ sep=' ' dicom_sr_codeMeaning_lst }".split()
			dicom_sr_CodingSchemeDesignator_lst = "~{ sep=' ' dicom_sr_CodingSchemeDesignator_lst }".split()
			terraRadSeriesDescription = "~{terraRadSeriesDescription}"
			SEG_OUTPUT = "~{SEG_OUTPUT}"
			res_scheme_format = "~{res_scheme_format}"

			# Create a dictionary with the list
			data = {
			'dicom_sr_CodeValues_lst' : dicom_sr_CodeValues_lst,
			'dicom_sr_codeMeaning_lst' : dicom_sr_codeMeaning_lst,
			'dicom_sr_CodingSchemeDesignator_lst' : dicom_sr_CodingSchemeDesignator_lst,
			'terraRadSeriesDescription' : terraRadSeriesDescription,
			'SEG_OUTPUT': SEG_OUTPUT,
			'OUTPUT_PATH': "/app/data/output_sr",
			'res_scheme_format': res_scheme_format
			}
			# Write the dictionary to a JSON file
			with open("/app/data/params_eval.yaml", "w") as outfile:
					yaml.dump(data, outfile, indent=4, allow_unicode=True)
			CODE
			# #wget notebook from github
			cd /app/data
			wget https://raw.githubusercontent.com/ccosmin97/idc-prostate-mri-analysis/main/terra_mhub/papermill_data/sr_dicom_generation.ipynb

			papermill /app/data/sr_dicom_generation.ipynb /app/data/sr_dicom_generation-output.ipynb -f /app/data/params_eval.yaml

			mkdir -p /app/data/radiomics_archive
			#create DICOM SEG/SR out folders
			mkdir -p /app/data/radiomics_archive/dicom_sr
			#move AI/IDC DICOM SEG objects to archive-ready folder
			mv /app/data/output_sr/seg_objects/dicom_sr /app/data/radiomics_archive/
			cp /app/data/sr_dicom_generation-output.ipynb /app/data/radiomics_archive/.

			tar -C /app/data/ -cvf - radiomics_archive | lz4 > /cromwell_root/radiomics_archive.tar.lz4
		>>>
		runtime {
			docker: docker
			cpu: cpus
			zones: cpuZones
			memory: ram + " GiB"
			bootDiskSizeGb: 50
			disks: "local-disk 10 HDD"
			preemptible: preemptibleTries
			maxRetries: maxRetries
		}
		output {
			File radiomicsCompressedOutputFile  = "radiomics_archive.tar.lz4"
		}
	}
	task combine_outputs_inference {
		  input {
				Array[File] aiSegOutputFiles
				Array[File] aiSrOutputFiles
				Array[String] mhub_model_name_lst

				#docker image path
				String docker

				#VM Config
				String cpuZones
				Int cpus
				Int ram
				Int preemptibleTries
			Int maxRetries
		}
		command  <<<
				mkdir -p /app/data
				mkdir -p /app/data/output_agg
				cd /app/data
				pip3 install pyyaml
				python3 <<CODE
				import json
				import yaml
				aiSegOutputFiles = "~{ sep=' ' aiSegOutputFiles }".split()
				aiSrOutputFiles = "~{ sep=' ' aiSrOutputFiles }".split()
				mhub_model_name_lst = "~{ sep=' ' mhub_model_name_lst }".split()
				# Create a dictionary with the list
				data = {
					'mhubCompressedOutputFiles' : aiSegOutputFiles,
					'radsAiCompressedOutputFiles' : aiSrOutputFiles,
					'mhub_model_name_lst' : mhub_model_name_lst,
					'OUTPUT_PATH': "/app/data/output_agg"}
				# Write the dictionary to a JSON file
				with open("/app/data/params_eval.yaml", "w") as outfile:
					yaml.dump(data, outfile, indent=4, allow_unicode=True)
				CODE
				#wget notebook from github
				cd /app/data
				wget https://raw.githubusercontent.com/ccosmin97/idc-prostate-mri-analysis/refs/heads/main/terra_mhub/papermill_data/combine_tasks_output_inference_only.ipynb
				papermill /app/data/combine_tasks_output_inference_only.ipynb /app/data/combine_tasks_output_inference_only-output.ipynb -f /app/data/params_eval.yaml
				#copy archive to cromwell output
				cp /app/data/output_agg/agg_archive.tar.lz4 /cromwell_root/agg_archive.tar.lz4
				cp /app/data/combine_tasks_output_inference_only-output.ipynb /cromwell_root/combine_tasks_output_inference_only-output.ipynb
		>>>
		  runtime {
				docker: docker
				cpu: cpus
				zones: cpuZones
				memory: ram + " GiB"
				bootDiskSizeGb: 50
				disks: "local-disk 10 HDD"
				preemptible: preemptibleTries
			maxRetries: maxRetries
		}
		output {
			File finalCompressedOutputFile = "agg_archive.tar.lz4"
		}
	}
	task ddl_idc_data {
		input {
			Array[String] t2SeriesInstanceUIDs
			Array[String] adcSeriesInstanceUIDs

			#docker image path
			String docker

			#VM Config
			String cpuZones
			Int cpus
			Int ram
			Int preemptibleTries
			Int maxRetries
		}
		command <<<
			pip install thedicomsort
			#multi-modality outputs
			mkdir -p /app/data/multi_modal_t2_adc_out/raw_idc_data
			mkdir -p /app/data/multi_modal_t2_adc_out/raw_idc_data/t2
			mkdir -p /app/data/multi_modal_t2_adc_out/raw_idc_data/adc
			mkdir -p /app/data/multi_modal_t2_adc_out/sorted_data
			#single-modality outputs
			mkdir -p /app/data/out_single_modal_t2_out
			mkdir -p /app/data/out_single_modal_t2_out/out_data
			#prepare output for multi-modality models
			idc download-from-selection --download-dir '/app/data/multi_modal_t2_adc_out/raw_idc_data/t2' --series-instance-uid  ~{sep=',' t2SeriesInstanceUIDs}
			idc download-from-selection --download-dir '/app/data/multi_modal_t2_adc_out/raw_idc_data/adc' --series-instance-uid  ~{sep=',' adcSeriesInstanceUIDs}
			dicomsort /app/data/multi_modal_t2_adc_out/raw_idc_data/t2 /app/data/multi_modal_t2_adc_out/sorted_data/%PatientID/%StudyInstanceUID/T2/%SOPInstanceUID.dcm
			dicomsort /app/data/multi_modal_t2_adc_out/raw_idc_data/adc /app/data/multi_modal_t2_adc_out/sorted_data/%PatientID/%StudyInstanceUID/ADC/%SOPInstanceUID.dcm
			#prepare output for single-modality models
			idc download-from-selection --download-dir '/app/data/out_single_modal_t2_out/out_data' --series-instance-uid  ~{sep=',' t2SeriesInstanceUIDs}
			# Compress multi-modal output data and move it to Cromwell root directory
			tar -C /app/data/multi_modal_t2_adc_out -cvf - sorted_data | lz4 > /cromwell_root/idc_data_multi_modal.tar.lz4
			tar -C /app/data/out_single_modal_t2_out -cvf - out_data | lz4 > /cromwell_root/idc_data_single_modal.tar.lz4
		>>>
		runtime {
			docker: docker
			cpu: cpus
			zones: cpuZones
			memory: ram + "GiB"
			bootDiskSizeGb: 50
			disks: "local-disk 10 HDD"
			preemptible: preemptibleTries
			maxRetries: maxRetries
		}
		output {
			File idcMultiModalDataCompressedOutputFile = "idc_data_multi_modal.tar.lz4"
			File idcSingleModalDataCompressedOutputFile = "idc_data_single_modal.tar.lz4"
		}
	}