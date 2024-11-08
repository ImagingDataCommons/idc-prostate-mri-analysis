# idc-prostate-mri-analysis

This repository contains all the code and data to replicate our analysis of AI-based publicly available MRI prostate segmentation methods. The structure is as follows:
- **terra_mhub** : folder containing terra.bio workflow details
- **analysis_notebooks** : folder containing python notebooks with quantitative and statistical analysis results.
- **prev_works** : folder containing previous symposium or workshops materials related to this study. 
- **analysis_results**: folder containing figures and results tables


### Summary of the study
Segmentation of the prostate and surrounding regions is important for a variety of clinical and research applications. Our goal is to evaluate the generalizability of publicly available state-of-the-art AI models on publicly available datasets. To compare the AI generated segmentations to the available manually annotated ground-truth, quantitative measures such as Dice Coefficient and Hausdorff distance, along with shape radiomics features, were analyzed. Our study also aims to show how cloud-based tools can be used to analyze, store, and visualize evaluation results. Our study results show variable performance of the AI models across the evaluated public collections. All of our analysis and results produced are meant to be publicly available. Evaluation of the AI methods is done through [Terra.bio](https://terra.bio/), allowing us to scale our analysis using the cloud, and [MHub.ai](https://mhub.ai/), which is an end-to-end DICOM-based platform for deep Learning models in medical imaging.

Our study focused on the evaluation of the pre-trained AI-based methods that were publicly available, and were accompanied by the peer-reviewed evidence demonstrating their performance, such as manuscripts describing and evaluating the methodology or documented successful participation in grand challenges. We selected two pre-trained models from the nnU-Net framework and the Prostate158 model, focusing on prostate gland and prostate zonal regions segmentation. The last model added for our study comes from the BAMF AIMI initiative, aiming to provide AI annotations for unlabelled collections in Imaging Data Commons . We chose a pre-trained for whole prostate gland segmentation coming from the BAMF team, trained using the nnU-Net framework. The selected models were then used to implement external evaluation on the publicly available manually annotated prostate MRI data from IDC.



### Replicating the analysis results through Terra.bio
To get started with Terra.bio workflows structure and running them, users could refer to [CloudSegmentator repository](https://github.com/ImagingDataCommons/CloudSegmentator?tab=readme-ov-file#terra).
To replicate the analysis, here are the components needed:
1. A Terra.bio/Google Cloud Computing (GCP) google account
2. The input data table containing for the Terra workflow (provided in this repository,  [terra_mhub_all_collections_v3_SITK_RES.tsv](terra_mhub/data_tables/terra_mhub_all_collections_v3_SITK_RES.tsv))
3. The [ProstateSegWorkflow.wdl](terra_mhub/wdl_scripts/ProstateSegWorkflow.wdl) main script (provided in this repository)

Even though the analysis has been made public and input and output data is transparent in our study, users still need a Terra.bio or GCP account with credits available. Users could acquire a fixed amount of credits for free, as first-time users, please see https://cloud.google.com/free. 
More granular information about the contents of the Terra workflow used is provided further below.

### terra_mhub folder structure
In this section  we will provide details about the files location of the Terra workflow : 
 -  [ProstateSegWorkflow.wdl](terra_mhub/wdl_scripts/ProstateSegWorkflow.wdl) : Terra.bio main workflow script.wdl that is use to run inference and evaluation of the AI models on Imaging Data Commons public prostate MRI focused collections.
 - [terra_mhub/papermill_notebooks](terra_mhub/papermill_notebooks) : python-based notebooks called inside the workflow.wdl for processing and evaluating the segmentation results from the AI segmentation methods. These notebooks are not designed to be run outside the workflow.
     -  [ai_mhub_seg_dicom_combination.ipynb](terra_mhub/papermill_notebooks/ai_mhub_seg_dicom_combination.ipynb) : input is Mhub produced DICOM SEG objects, output is DICOM SEG objects with added whole prostate gland(fusion of Peripheral Zone and Transition Zone of the prostate) segment.
     -  [idc_seg_dicom_combination.ipynb](terra_mhub/papermill_notebooks/idc_seg_dicom_combination.ipynb) : downloading of expert annotations DICOM SEG objects and adding if necessary the whole prostate gland segment.  
     - [sr_dicom_generation.ipynb](terra_mhub/papermill_notebooks/sr_dicom_generation.ipynb) : generation of DICOM Structured Reports objects from DICOM SEG objects, storing for example segments mesh volumes.
     -  [seg_dicom_eval.ipynb](terra_mhub/papermill_notebooks/seg_dicom_eval.ipynb) : input  is AI and expert DICOM SEG objects, output is quantitative analysis(DSC,HD) stored in csv files.
     -  [combine_tasks_output.ipynb](terra_mhub/papermill_notebooks/combine_tasks_output.ipynb) : Organization of AI DICOM SEG/SR and quantitative analysis results into a structured otput folder.
-  [terra_mhub_all_collections_v3_SITK_RES.tsv](terra_mhub/data_tables/terra_mhub_all_collections_v3_SITK_RES.tsv): input data table serving as input for the [ProstateSegWorkflow.wdl](terra_mhub/wdl_scripts/ProstateSegWorkflow.wdl)
-   [bigquery_join_seg_sr_analysis_results.ipynb](terra_mhub/process_terra_out/bigquery_join_seg_sr_analysis_results.ipynb): join AI SEG/SR and analysis results together through BigQuery.
-   [process_terra_outputs.ipynb](terra_mhub/process_terra_out/process_terra_outputs.ipynb): retrieve terra workflow output files stored in GCP buckets,organize them and export them to GCP buckets, dicom stores and BigQuery tables.
-   [terra_data_table_setup_tsv_all.ipynb](terra_mhub/terra_data_table_setup_tsv_all.ipynb) : python notebook aiming to create [terra_mhub_all_collections_v3_SITK_RES.tsv](terra_mhub/data_tables/terra_mhub_all_collections_v3_SITK_RES.tsv) from querying Imaging Data Commons data through BigQuery. 

### analysis_notebooks 
In this section  we will provide details about the files location of the analysis results :
-  [stats_summary.ipynb](analysis_notebooks/stats_summary.ipynb) : quantitative analysis summary table statistics in a python notebook.
-  [plots_analysis.ipynb](analysis_notebooks/plots_analysis.ipynb) : python notebook for visualization plots.
- [analysis_statistical_testing.ipynb](analysis_notebooks/analysis_statistical_testing.ipynb) : python notebook for statistical analysis.
 
### analysis_results folder items
- [analysis_results.csv](analysis_results/analysis_results.csv) : csv file containing all analysis results.
- [analysis_results_prostatex_inf_only.csv](analysis_results/analysis_results_prostatex_inf_only.csv) : csv file containing prostatex collection inference-only results.
