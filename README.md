# idc-prostate-mri-analysis

Example notebooks grouping prostate anatomy segmentation use cases, using MONAI or nnUNet on IDC publicly available prostate MRI data.

The **pcDetectionBundle** contains the experimental monai bundle we created for prostate cancer segmentation application on IDC data, based on already available MONAI prostate158 bundle.

The symposium notebooks folder contains examples on, using nnUNet pre-trained segmentation model, how to :

 - Download IDC data
 - Pre-process IDC data and convert to nifti from DICOM representation
 - Inference using the pre-trained model
 - Evaluation
 
Everything above runs on Google Colab, custom paths to GCP tools are not public, work mentioned above is to showcase the specific steps leading to analysis results.

In the symposium folder, structure of the files is: {model name} _ {collection evaluated} _ {step (inference/analysis/radiomics)}.

## prostate_segmentation_notebooks

This folder contains a subset of the deep learning prostate segmentation analysis on Imaging Data Commons data. 
This folder contains .csv files with results of quantitative analysis of gold standard segmentations and AI predictions(Dice Coefficient, Hausdorff distance, Average surface distance), along with radiomics computation(volume, sphericity).

Evaluated model is a deep-learning based prostate segmentation model trained on the Promise12 challenge dataset using the nnUNet framework.
The framework and the model pre-trained weights were made available by the [MIC-DKFZ team](https://github.com/MIC-DKFZ).

It was evaluated on IDC prostate cancer collections, namely ProstateX, QIN-Prostate-Repeatability and Prostate-MRI-US-Biopsy.

The radiology_papers_figures notebook contains figures showing the DSC of mentioned above model on the IDC collections, and a volume analysis on QIN-Prostate-Repeatability collection.

![image](https://github.com/ccosmin97/idc-prostate-mri-analysis/assets/72577931/23a02f86-bfc8-490d-bf55-d2e5c1273e2e)
