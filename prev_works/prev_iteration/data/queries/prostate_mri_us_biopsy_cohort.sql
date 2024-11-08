WITH
  # select segmentations - legacy
  idc_seg_whole_prostate AS(
  SELECT
    DISTINCT dc_all3.SeriesInstanceUID,
    dc_all3.ReferencedSeriesSequence[SAFE_OFFSET(0)].SeriesInstanceUID AS image_serieUID,
    dc_all3.SeriesDescription,
    dc_all3.StudyInstanceUID
  FROM
    `bigquery-public-data.idc_current.dicom_all` AS dc_all3
  WHERE
    collection_id = 'prostate_mri_us_biopsy'
    AND SegmentSequence[SAFE_OFFSET(0)].SegmentedPropertyTypeCodeSequence[SAFE_OFFSET(0)].CodingSchemeDesignator = 'SCT'
    AND SegmentSequence[SAFE_OFFSET(0)].SegmentedPropertyTypeCodeSequence[SAFE_OFFSET(0)].CodeValue = '41216001'
    AND SeriesDescription NOT LIKE '%AIMI%'
    AND SegmentSequence[SAFE_OFFSET(0)].SegmentAlgorithmType IN UNNEST(['MANUAL', 'SEMIAUTOMATIC'])
    AND Modality = 'SEG'),
  # cleaned up segmentations selection
  # we know there is only one prostate segmentation per study
  idc_seg_whole_prostate_new AS (
  SELECT
    segmentations.StudyInstanceUID,
    segmentations.SeriesInstanceUID,
    segmentations.segmented_SeriesInstanceUID,
    # for debugging:
    dicom_all.SeriesDescription
  FROM
    `bigquery-public-data.idc_current.segmentations` AS segmentations
  JOIN
    `bigquery-public-data.idc_current.dicom_all` AS dicom_all
  ON
    segmentations.SeriesInstanceUID = dicom_all.SeriesInstanceUID
  WHERE
    dicom_all.analysis_result_id = "Prostate-MRI-US-Biopsy-DICOM-Annotations"
    # the next line is equivalent, but less clear
    #lower(dicom_all.source_doi) = "10.5281/zenodo.10069910"
    AND segmentations.SegmentedPropertyType.CodeValue = '41216001'
    AND segmentations.SegmentedPropertyType.CodingSchemeDesignator = 'SCT' ),
  # select T2, here we do not check for multiple T2 within the same study, since we know there is only one per study
  t2_series AS(
  SELECT
    DISTINCT dc_all.SeriesInstanceUID,
    dc_all.StudyInstanceUID,
    dc_all.PatientID
  FROM
    `bigquery-public-data.idc_current.dicom_all` AS dc_all
  WHERE
    dc_all.collection_id = 'prostate_mri_us_biopsy'
    AND dc_all.Modality = 'MR'
    AND LOWER(dc_all.SeriesDescription) LIKE '%t2%'
  ORDER BY
    PatientID),
  # ADC selection, but since we know there are studies with more than one, we select the latest
  adc_series AS(
  SELECT
    dc_adc.StudyInstanceUID,
    ARRAY_AGG(dc_adc.SeriesInstanceUID
    ORDER BY
      dc_adc.SeriesDate, dc_adc.SeriesTime DESC
    LIMIT
      1)[SAFE_OFFSET(0)] AS SeriesInstanceUID,
  FROM
    `bigquery-public-data.idc_current.dicom_all` AS dc_adc
  JOIN
    t2_series
  ON
    dc_adc.StudyInstanceUID = t2_series.StudyInstanceUID
  WHERE
    LOWER(dc_adc.SeriesDescription) LIKE '%adc%'
  GROUP BY
    dc_adc.StudyInstanceUID)
SELECT
  t2_series.SeriesInstanceUID AS t2_serieUID,
  adc_series.SeriesInstanceUID AS adc_serieUID,
  idc_seg_whole_prostate_new.SeriesInstanceUID AS expertWholeProstateSeriesInstanceUID,
  #idc_seg_whole_prostate.SeriesDescription AS expertWholeProstateSeriesDescription,
  t2_series.StudyInstanceUID
FROM
  t2_series
INNER JOIN
  adc_series
ON
  t2_series.StudyInstanceUID = adc_series.StudyInstanceUID
INNER JOIN
  idc_seg_whole_prostate_new
ON
  t2_series.SeriesInstanceUID = idc_seg_whole_prostate_new.segmented_SeriesInstanceUID