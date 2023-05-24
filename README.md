# idc-prostate-mri-analysis

Example notebooks grouping prostate anatomy segmentation use cases, using MONAI or nnUNet on IDC publicly available prostate MRI data.

The **pcDetectionBundle contains the experimental monai bundle we created for prostate cancer segmentation application on IDC data, based on already available MONAI prostate158 bundle.**

The symposium notebooks folder contains examples on, using nnUNet pre-trained segmentation model, how to :

 - Download IDC data
 - Pre-process IDC data and convert to nifti from DICOM representation
 - Inference using the pre-trained model
 - Evaluation
 
Everything above runs on Google Colab, custom paths to GCP tools are not public, work mentioned above is to showcase the specific steps leading to analysis results.

In the symposium folder, structure of the files is : {model name} _ {collection evaluated} _ {step (inference/analysis/radiomics)}.
